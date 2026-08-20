using System.Text;
using Herdr.Windows.Terminal;

namespace Herdr.Windows.Tests;

public sealed class ConPtySessionTests
{
    [Theory]
    [InlineData("plain", "plain")]
    [InlineData("two words", "\"two words\"")]
    [InlineData("", "\"\"")]
    [InlineData("say \"hi\"", "\"say \\\"hi\\\"\"")]
    public void QuotesWindowsCommandLineArguments(string value, string expected)
    {
        Assert.Equal(expected, ConPtySession.QuoteArgument(value));
    }

    [Fact]
    public async Task CapturesOutputFromARealPseudoConsole()
    {
        var command = Environment.GetEnvironmentVariable("COMSPEC") ?? @"C:\Windows\System32\cmd.exe";
        var output = new StringBuilder();
        var completed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        await using var session = ConPtySession.Start(command, ["/d"]);
        session.OutputReceived += value =>
        {
            output.Append(value);
            if (output.ToString().Contains("HERDR_CONPTY_OK", StringComparison.Ordinal)) completed.TrySetResult();
        };
        await session.WriteAsync("echo HERDR_CONPTY_OK\r");

        try
        {
            await completed.Task.WaitAsync(TimeSpan.FromSeconds(10));
        }
        catch (TimeoutException exception)
        {
            var diagnostics = $"ConPTY produced no marker. {session.GetDebugState()} rawOutput={output}";
            Console.Error.WriteLine(diagnostics);
            throw new TimeoutException(diagnostics, exception);
        }

        Assert.Contains("HERDR_CONPTY_OK", output.ToString());
        await session.WriteAsync("exit\r");
    }
}
