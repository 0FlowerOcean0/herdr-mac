using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Herdr.Windows.Terminal;

public sealed class ConPtySession : IAsyncDisposable
{
    private const uint ExtendedStartupInfoPresent = 0x00080000;
    private const uint CreateUnicodeEnvironment = 0x00000400;
    private static readonly IntPtr ProcThreadAttributePseudoConsole = new(0x00020016);

    private readonly FileStream _input;
    private readonly FileStream _output;
    private readonly SemaphoreSlim _inputLock = new(1, 1);
    private readonly CancellationTokenSource _cancellation = new();
    private readonly object _eventLock = new();
    private readonly StringBuilder _pendingOutput = new();
    private readonly Task _readerTask;
    private IntPtr _pseudoConsole;
    private bool _disposed;
    private bool _hasExited;
    private Action<string>? _outputReceived;
    private Action? _exited;

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

    private ConPtySession(IntPtr pseudoConsole, SafeFileHandle input, SafeFileHandle output)
    {
        _pseudoConsole = pseudoConsole;
        // CreatePipe returns synchronous handles. FileStream still provides Task-based
        // reads/writes for them, but the handles must not be marked as overlapped I/O.
        _input = new FileStream(input, FileAccess.Write, 4096, false);
        _output = new FileStream(output, FileAccess.Read, 4096, false);
        _readerTask = Task.Run(ReadOutputAsync);
    }

    public static ConPtySession Start(
        string executable,
        IReadOnlyList<string>? arguments = null,
        string? workingDirectory = null,
        short columns = 120,
        short rows = 36,
        IReadOnlyDictionary<string, string?>? environmentOverrides = null)
    {
        if (!File.Exists(executable)) throw new FileNotFoundException("The terminal executable was not found.", executable);
        if (columns < 1 || rows < 1) throw new ArgumentOutOfRangeException(nameof(columns), "The terminal size must be positive.");

        IntPtr pseudoInputRead = IntPtr.Zero;
        IntPtr hostInputWrite = IntPtr.Zero;
        IntPtr hostOutputRead = IntPtr.Zero;
        IntPtr pseudoOutputWrite = IntPtr.Zero;
        IntPtr pseudoConsole = IntPtr.Zero;
        IntPtr attributeList = IntPtr.Zero;
        IntPtr pseudoConsoleValue = IntPtr.Zero;
        IntPtr environmentBlock = IntPtr.Zero;

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
            if (result < 0) Marshal.ThrowExceptionForHR(result);

            NativeMethods.CloseHandle(pseudoInputRead);
            pseudoInputRead = IntPtr.Zero;
            NativeMethods.CloseHandle(pseudoOutputWrite);
            pseudoOutputWrite = IntPtr.Zero;

            var attributeListSize = IntPtr.Zero;
            NativeMethods.InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref attributeListSize);
            attributeList = Marshal.AllocHGlobal(attributeListSize);
            if (!NativeMethods.InitializeProcThreadAttributeList(attributeList, 1, 0, ref attributeListSize))
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not initialize the ConPTY process attributes.");
            }

            pseudoConsoleValue = Marshal.AllocHGlobal(IntPtr.Size);
            Marshal.WriteIntPtr(pseudoConsoleValue, pseudoConsole);
            if (!NativeMethods.UpdateProcThreadAttribute(
                    attributeList,
                    0,
                    ProcThreadAttributePseudoConsole,
                    pseudoConsoleValue,
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
            environmentBlock = BuildEnvironmentBlock(environmentOverrides);
            var processCreated = NativeMethods.CreateProcessW(
                executable,
                commandLine,
                IntPtr.Zero,
                IntPtr.Zero,
                false,
                ExtendedStartupInfoPresent | CreateUnicodeEnvironment,
                environmentBlock,
                ResolveWorkingDirectory(workingDirectory),
                ref startupInfo,
                out var processInfo);
            if (!processCreated)
            {
                throw new Win32Exception(Marshal.GetLastWin32Error(), $"Could not start {Path.GetFileName(executable)} through ConPTY.");
            }

            NativeMethods.CloseHandle(processInfo.Thread);
            NativeMethods.CloseHandle(processInfo.Process);

            var inputHandle = new SafeFileHandle(hostInputWrite, true);
            hostInputWrite = IntPtr.Zero;
            var outputHandle = new SafeFileHandle(hostOutputRead, true);
            hostOutputRead = IntPtr.Zero;
            return new ConPtySession(pseudoConsole, inputHandle, outputHandle);
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
            if (pseudoConsoleValue != IntPtr.Zero) Marshal.FreeHGlobal(pseudoConsoleValue);
            if (environmentBlock != IntPtr.Zero) Marshal.FreeHGlobal(environmentBlock);
        }
    }

    public async Task WriteAsync(string data, CancellationToken cancellationToken = default)
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (string.IsNullOrEmpty(data)) return;
        var bytes = Encoding.UTF8.GetBytes(data);
        await _inputLock.WaitAsync(cancellationToken);
        try
        {
            await _input.WriteAsync(bytes, cancellationToken);
            await _input.FlushAsync(cancellationToken);
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
        if (_pseudoConsole != IntPtr.Zero)
        {
            var pseudoConsole = _pseudoConsole;
            _pseudoConsole = IntPtr.Zero;
            await Task.Run(() => NativeMethods.ClosePseudoConsole(pseudoConsole));
        }
        try
        {
            await _readerTask.WaitAsync(TimeSpan.FromSeconds(2));
        }
        catch (TimeoutException)
        {
            _cancellation.Cancel();
            _output.Dispose();
        }
        catch (OperationCanceledException)
        {
            // Expected when reconnecting or closing the window.
        }
        _output.Dispose();
        _inputLock.Dispose();
        _cancellation.Dispose();
    }

    private async Task ReadOutputAsync()
    {
        var decoder = Encoding.UTF8.GetDecoder();
        var bytes = new byte[8192];
        var characters = new char[8192];
        try
        {
            while (!_cancellation.IsCancellationRequested)
            {
                var count = await _output.ReadAsync(bytes, _cancellation.Token);
                if (count == 0) break;
                var characterCount = decoder.GetChars(bytes, 0, count, characters, 0, false);
                if (characterCount > 0) PublishOutput(new string(characters, 0, characterCount));
            }
        }
        catch (OperationCanceledException)
        {
            // Session disposal cancels the pipe read.
        }
        catch (IOException)
        {
            // Closing a pseudoconsole ends its pipe with ERROR_BROKEN_PIPE.
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

    private static StringBuilder BuildCommandLine(string executable, IReadOnlyList<string> arguments)
    {
        var values = new[] { executable }.Concat(arguments).Select(QuoteArgument);
        return new StringBuilder(string.Join(' ', values));
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

    private static IntPtr BuildEnvironmentBlock(IReadOnlyDictionary<string, string?>? overrides)
    {
        var environment = Environment.GetEnvironmentVariables()
            .Cast<System.Collections.DictionaryEntry>()
            .ToDictionary(entry => (string)entry.Key, entry => entry.Value?.ToString() ?? string.Empty, StringComparer.OrdinalIgnoreCase);
        environment["TERM"] = "xterm-256color";
        environment["COLORTERM"] = "truecolor";
        if (overrides is not null)
        {
            foreach (var pair in overrides)
            {
                if (pair.Value is null) environment.Remove(pair.Key);
                else environment[pair.Key] = pair.Value;
            }
        }
        var block = string.Join('\0', environment.OrderBy(pair => pair.Key, StringComparer.OrdinalIgnoreCase).Select(pair => $"{pair.Key}={pair.Value}")) + "\0\0";
        return Marshal.StringToHGlobalUni(block);
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

    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfoEx
    {
        public StartupInfo StartupInfo;
        public IntPtr AttributeList;
    }

    [StructLayout(LayoutKind.Sequential)]
    private readonly struct ProcessInformation
    {
        public readonly IntPtr Process;
        public readonly IntPtr Thread;
        public readonly uint ProcessId;
        public readonly uint ThreadId;
    }

    private static class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreatePipe(out IntPtr readPipe, out IntPtr writePipe, IntPtr pipeAttributes, uint size);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CloseHandle(IntPtr handle);

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

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        internal static extern bool CreateProcessW(
            string? applicationName,
            StringBuilder commandLine,
            IntPtr processAttributes,
            IntPtr threadAttributes,
            [MarshalAs(UnmanagedType.Bool)] bool inheritHandles,
            uint creationFlags,
            IntPtr environment,
            string? currentDirectory,
            ref StartupInfoEx startupInfo,
            out ProcessInformation processInformation);
    }
}
