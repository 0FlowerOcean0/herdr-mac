using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Herdr.Windows.Terminal;

public sealed class ConPtySession : IAsyncDisposable
{
    private const uint ExtendedStartupInfoPresent = 0x00080000;
    private static readonly IntPtr ProcThreadAttributePseudoConsole = new(0x00020016);

    private readonly SafeFileHandle _input;
    private readonly SafeFileHandle _output;
    private readonly SafeFileHandle _pseudoInput;
    private readonly SafeFileHandle _pseudoOutput;
    private readonly SafeFileHandle _process;
    private readonly SemaphoreSlim _inputLock = new(1, 1);
    private readonly object _eventLock = new();
    private readonly StringBuilder _pendingOutput = new();
    private readonly Task _readerTask;
    private IntPtr _pseudoConsole;
    private IntPtr _attributeList;
    private bool _disposed;
    private bool _hasExited;
    private Action<string>? _outputReceived;
    private Action? _exited;
    private volatile bool _readerStarted;
    private string? _readerError;

    public event Action<string>? OutputReceived
    {
        add
        {
            string pending;
            lock (_eventLock)
            {
                _outputReceived += value;
                pending = _pendingOutput.ToString();
                _pendingOutput.Clear();
            }
            if (pending.Length > 0) value?.Invoke(pending);
        }
        remove
        {
            lock (_eventLock) _outputReceived -= value;
        }
    }

    public event Action? Exited
    {
        add
        {
            var invokeNow = false;
            lock (_eventLock)
            {
                _exited += value;
                invokeNow = _hasExited;
            }
            if (invokeNow) value?.Invoke();
        }
        remove
        {
            lock (_eventLock) _exited -= value;
        }
    }

    private ConPtySession(
        IntPtr pseudoConsole,
        IntPtr attributeList,
        SafeFileHandle input,
        SafeFileHandle output,
        SafeFileHandle pseudoInput,
        SafeFileHandle pseudoOutput,
        SafeFileHandle process)
    {
        _pseudoConsole = pseudoConsole;
        _attributeList = attributeList;
        _process = process;
        _input = input;
        _output = output;
        _pseudoInput = pseudoInput;
        _pseudoOutput = pseudoOutput;
        _readerTask = Task.Factory.StartNew(
            ReadOutput,
            CancellationToken.None,
            TaskCreationOptions.LongRunning,
            TaskScheduler.Default);
    }

    public static ConPtySession Start(
        string executable,
        IReadOnlyList<string>? arguments = null,
        string? workingDirectory = null,
        short columns = 120,
        short rows = 36)
    {
        if (!File.Exists(executable)) throw new FileNotFoundException("The terminal executable was not found.", executable);
        if (columns < 1 || rows < 1) throw new ArgumentOutOfRangeException(nameof(columns), "The terminal size must be positive.");

        IntPtr pseudoInputRead = IntPtr.Zero;
        IntPtr hostInputWrite = IntPtr.Zero;
        IntPtr hostOutputRead = IntPtr.Zero;
        IntPtr pseudoOutputWrite = IntPtr.Zero;
        IntPtr pseudoConsole = IntPtr.Zero;
        IntPtr attributeList = IntPtr.Zero;

        try
        {
            CreatePipeOrThrow(out pseudoInputRead, out hostInputWrite);
            CreatePipeOrThrow(out hostOutputRead, out pseudoOutputWrite);

            var result = NativeMethods.CreatePseudoConsole(
                new Coord(columns, rows),
                pseudoInputRead,
                pseudoOutputWrite,
                0,
                out pseudoConsole);
            if (result != 0) Marshal.ThrowExceptionForHR(result);

            var attributeListSize = IntPtr.Zero;
            NativeMethods.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attributeListSize);
            attributeList = Marshal.AllocHGlobal(attributeListSize);
            if (!NativeMethods.InitializeProcThreadAttributeList(attributeList, 1, 0, ref attributeListSize))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not initialize the ConPTY process attributes.");
            }

            if (!NativeMethods.UpdateProcThreadAttribute(
                    attributeList,
                    0,
                    ProcThreadAttributePseudoConsole,
                    pseudoConsole,
                    new IntPtr(IntPtr.Size),
                    IntPtr.Zero,
                    IntPtr.Zero))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not attach the ConPTY process attribute.");
            }

            var startupInfo = new StartupInfoEx
            {
                StartupInfo = new StartupInfo { Size = Marshal.SizeOf<StartupInfoEx>() },
                AttributeList = attributeList
            };
            var commandLine = BuildCommandLine(executable, arguments ?? []);
            var securityAttributesSize = Marshal.SizeOf<SecurityAttributes>();
            var processAttributes = new SecurityAttributes { Length = securityAttributesSize };
            var threadAttributes = new SecurityAttributes { Length = securityAttributesSize };
            var processCreated = NativeMethods.CreateProcess(
                null,
                commandLine,
                ref processAttributes,
                ref threadAttributes,
                false,
                ExtendedStartupInfoPresent,
                IntPtr.Zero,
                ResolveWorkingDirectory(workingDirectory),
                ref startupInfo,
                out var processInfo);
            if (!processCreated)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), $"Could not start {Path.GetFileName(executable)} through ConPTY.");
            }

            NativeMethods.CloseHandle(processInfo.Thread);
            var processHandle = new SafeFileHandle(processInfo.Process, true);

            var inputHandle = new SafeFileHandle(hostInputWrite, true);
            hostInputWrite = IntPtr.Zero;
            var outputHandle = new SafeFileHandle(hostOutputRead, true);
            hostOutputRead = IntPtr.Zero;
            var pseudoInputHandle = new SafeFileHandle(pseudoInputRead, true);
            pseudoInputRead = IntPtr.Zero;
            var pseudoOutputHandle = new SafeFileHandle(pseudoOutputWrite, true);
            pseudoOutputWrite = IntPtr.Zero;
            var ownedAttributeList = attributeList;
            attributeList = IntPtr.Zero;
            return new ConPtySession(
                pseudoConsole,
                ownedAttributeList,
                inputHandle,
                outputHandle,
                pseudoInputHandle,
                pseudoOutputHandle,
                processHandle);
        }
        catch
        {
            if (pseudoConsole != IntPtr.Zero) NativeMethods.ClosePseudoConsole(pseudoConsole);
            throw;
        }
        finally
        {
            CloseIfValid(pseudoInputRead);
            CloseIfValid(hostInputWrite);
            CloseIfValid(hostOutputRead);
            CloseIfValid(pseudoOutputWrite);
            if (attributeList != IntPtr.Zero)
            {
                NativeMethods.DeleteProcThreadAttributeList(attributeList);
                Marshal.FreeHGlobal(attributeList);
            }
        }
    }

    public async Task WriteAsync(string data, CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (string.IsNullOrEmpty(data)) return;
        await _inputLock.WaitAsync(cancellationToken);
        try
        {
            var bytes = Encoding.UTF8.GetBytes(data);
            await Task.Run(() =>
            {
                if (!NativeMethods.WriteFile(_input.DangerousGetHandle(), bytes, (uint)bytes.Length, out var written, IntPtr.Zero))
                {
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not write terminal input to ConPTY.");
                }
                if (written != (uint)bytes.Length) throw new IOException("ConPTY accepted only part of the terminal input.");
            }, cancellationToken);
        }
        finally
        {
            _inputLock.Release();
        }
    }

    public void Resize(short columns, short rows)
    {
        if (_disposed || _pseudoConsole == IntPtr.Zero || columns < 1 || rows < 1) return;
        var result = NativeMethods.ResizePseudoConsole(_pseudoConsole, new Coord(columns, rows));
        if (result < 0) Marshal.ThrowExceptionForHR(result);
    }

    public async ValueTask DisposeAsync()
    {
        if (_disposed) return;
        _disposed = true;
        _input.Dispose();
        if (NativeMethods.GetExitCodeProcess(_process, out var exitCode) && exitCode == 259)
        {
            NativeMethods.TerminateProcess(_process, 1);
        }
        _output.Dispose();
        try
        {
            await _readerTask.WaitAsync(TimeSpan.FromSeconds(2));
        }
        catch (TimeoutException)
        {
            // The dedicated listener owns no other resources after the pipe closes.
        }
        if (_pseudoConsole != IntPtr.Zero)
        {
            var pseudoConsole = _pseudoConsole;
            _pseudoConsole = IntPtr.Zero;
            var closeTask = Task.Run(() => NativeMethods.ClosePseudoConsole(pseudoConsole));
            await Task.WhenAny(closeTask, Task.Delay(TimeSpan.FromSeconds(2)));
        }
        _pseudoInput.Dispose();
        _pseudoOutput.Dispose();
        if (_attributeList != IntPtr.Zero)
        {
            NativeMethods.DeleteProcThreadAttributeList(_attributeList);
            Marshal.FreeHGlobal(_attributeList);
            _attributeList = IntPtr.Zero;
        }
        _process.Dispose();
        _inputLock.Dispose();
    }

    internal string GetDebugState()
    {
        var processState = NativeMethods.GetExitCodeProcess(_process, out var exitCode)
            ? exitCode.ToString()
            : $"error:{Marshal.GetLastWin32Error()}";
        return $"processExit={processState}; readerStarted={_readerStarted}; readerError={_readerError ?? "none"}";
    }

    private void ReadOutput()
    {
        _readerStarted = true;
        var decoder = Encoding.UTF8.GetDecoder();
        var bytes = new byte[8192];
        var characters = new char[8192];
        try
        {
            while (true)
            {
                if (!NativeMethods.ReadFile(_output.DangerousGetHandle(), bytes, (uint)bytes.Length, out var count, IntPtr.Zero))
                {
                    var error = Marshal.GetLastWin32Error();
                    if (error == 109 || error == 232 || _disposed) break;
                    throw new Win32Exception(error, "Could not read ConPTY output.");
                }
                if (count == 0) break;
                var characterCount = decoder.GetChars(bytes, 0, (int)count, characters, 0, false);
                if (characterCount > 0) PublishOutput(new string(characters, 0, characterCount));
            }
        }
        catch (Win32Exception exception)
        {
            _readerError = $"win32:{exception.NativeErrorCode}:{exception.Message}";
        }
        catch (ObjectDisposedException exception)
        {
            // A forced reconnect closes the read pipe to unblock the listener.
            _readerError = exception.Message;
        }
        finally
        {
            Action? handler;
            lock (_eventLock)
            {
                _hasExited = true;
                handler = _exited;
            }
            handler?.Invoke();
        }
    }

    private void PublishOutput(string output)
    {
        Action<string>? handler;
        lock (_eventLock)
        {
            handler = _outputReceived;
            if (handler is null)
            {
                _pendingOutput.Append(output);
                return;
            }
        }
        handler.Invoke(output);
    }

    private static void CreatePipeOrThrow(out IntPtr readPipe, out IntPtr writePipe)
    {
        if (!NativeMethods.CreatePipe(out readPipe, out writePipe, IntPtr.Zero, 0))
        {
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not create a ConPTY pipe.");
        }
    }

    private static string BuildCommandLine(string executable, IReadOnlyList<string> arguments)
    {
        var values = new[] { executable }.Concat(arguments).Select(QuoteArgument);
        return string.Join(' ', values);
    }

    internal static string QuoteArgument(string value)
    {
        if (value.Length > 0 && !value.Any(character => char.IsWhiteSpace(character) || character == '\"')) return value;
        var result = new StringBuilder("\"");
        var backslashes = 0;
        foreach (var character in value)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }
            if (character == '\"')
            {
                result.Append('\\', backslashes * 2 + 1);
                result.Append('\"');
                backslashes = 0;
                continue;
            }
            result.Append('\\', backslashes);
            backslashes = 0;
            result.Append(character);
        }
        result.Append('\\', backslashes * 2);
        result.Append('\"');
        return result.ToString();
    }

    private static string ResolveWorkingDirectory(string? requested)
    {
        if (!string.IsNullOrWhiteSpace(requested) && Directory.Exists(requested)) return Path.GetFullPath(requested);
        return Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    }

    private static void CloseIfValid(IntPtr handle)
    {
        if (handle != IntPtr.Zero && handle != new IntPtr(-1)) NativeMethods.CloseHandle(handle);
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct Coord(short x, short y)
    {
        public readonly short X = x;
        public readonly short Y = y;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo
    {
        public int Size;
        public string? Reserved;
        public string? Desktop;
        public string? Title;
        public int X;
        public int Y;
        public int XSize;
        public int YSize;
        public int XCountChars;
        public int YCountChars;
        public int FillAttribute;
        public int Flags;
        public short ShowWindow;
        public short Reserved2Count;
        public IntPtr Reserved2;
        public IntPtr StandardInput;
        public IntPtr StandardOutput;
        public IntPtr StandardError;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfoEx
    {
        public StartupInfo StartupInfo;
        public IntPtr AttributeList;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public IntPtr Process;
        public IntPtr Thread;
        public uint ProcessId;
        public uint ThreadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SecurityAttributes
    {
        public int Length;
        public IntPtr SecurityDescriptor;
        public int InheritHandle;
    }

    private static class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreatePipe(out IntPtr readPipe, out IntPtr writePipe, IntPtr pipeAttributes, uint size);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseHandle(IntPtr handle);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool GetExitCodeProcess(SafeFileHandle process, out uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool TerminateProcess(SafeFileHandle process, uint exitCode);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool ReadFile(
            IntPtr file,
            [Out] byte[] buffer,
            uint bytesToRead,
            out uint bytesRead,
            IntPtr overlapped);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool WriteFile(
            IntPtr file,
            byte[] buffer,
            uint bytesToWrite,
            out uint bytesWritten,
            IntPtr overlapped);

        [DllImport("kernel32.dll")]
        internal static extern int CreatePseudoConsole(Coord size, IntPtr input, IntPtr output, uint flags, out IntPtr pseudoConsole);

        [DllImport("kernel32.dll")]
        internal static extern int ResizePseudoConsole(IntPtr pseudoConsole, Coord size);

        [DllImport("kernel32.dll")]
        internal static extern void ClosePseudoConsole(IntPtr pseudoConsole);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool InitializeProcThreadAttributeList(IntPtr attributeList, int attributeCount, int flags, ref IntPtr size);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool UpdateProcThreadAttribute(
            IntPtr attributeList,
            uint flags,
            IntPtr attribute,
            IntPtr value,
            IntPtr size,
            IntPtr previousValue,
            IntPtr returnSize);

        [DllImport("kernel32.dll")]
        internal static extern void DeleteProcThreadAttributeList(IntPtr attributeList);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreateProcess(
            string? applicationName,
            string commandLine,
            ref SecurityAttributes processAttributes,
            ref SecurityAttributes threadAttributes,
            [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
            uint creationFlags,
            IntPtr environment,
            string? currentDirectory,
            [In] ref StartupInfoEx startupInfo,
            out ProcessInformation processInformation);
    }
}
