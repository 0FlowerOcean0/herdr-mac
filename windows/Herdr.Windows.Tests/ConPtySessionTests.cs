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

}
