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
        var command = Environment.GetEnvironmentVariable("HERDR_CONPTY_TEST_HOST");
        Assert.True(File.Exists(command), "HERDR_CONPTY_TEST_HOST must point to the published CI test host.");
        var output = new StringBuilder();
        var ready = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        var echoed = new TaskCompletionSource(TaskCreationOptions.RunContinuationsAsynchronously);
        await using var session = ConPtySession.Start(command!);
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
        }
        catch (TimeoutException exception)
        {
            var diagnostics = $"ConPTY produced no marker. {session.GetDebugState()} rawOutput={output}";
            Console.Error.WriteLine(diagnostics);
            throw new TimeoutException(diagnostics, exception);
        }

        Assert.Contains("HERDR_CONPTY_READY", output.ToString());
        Assert.Contains("HERDR_CONPTY_ECHO:PING", output.ToString());
    }
}
