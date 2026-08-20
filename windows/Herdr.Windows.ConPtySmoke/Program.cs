using System.Text;
using Herdr.Windows.Terminal;

if (args.Length != 1 || !File.Exists(args[0]))
{
    Console.Error.WriteLine("Usage: Herdr.Windows.ConPtySmoke <test-host.exe>");
    return 2;
}

var output = new StringBuilder();
var ready = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
var echoed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
await using var session = ConPtySession.Start(args[0]);
session.OutputReceived += value =>
{
    output.Append(value);
    var current = output.ToString();
    if (current.Contains("HERDR_CONPTY_READY", StringComparison.Ordinal)) ready.TrySetResult();
    if (current.Contains("HERDR_CONPTY_ECHO:PING", StringComparison.Ordinal)) echoed.TrySetResult();
};

try
{
    await ready.Task.WaitAsync(TimeSpan.FromSeconds(10));
    await session.WriteAsync("PING\r");
    await echoed.Task.WaitAsync(TimeSpan.FromSeconds(10));
    Console.WriteLine("ConPTY smoke test passed: output and input round-trip are working.");
    return 0;
}
catch (Exception exception)
{
    Console.Error.WriteLine($"ConPTY smoke test failed: {exception.Message}");
    Console.Error.WriteLine(session.GetDebugState());
    Console.Error.WriteLine($"Raw output: {output}");
    return 1;
}
