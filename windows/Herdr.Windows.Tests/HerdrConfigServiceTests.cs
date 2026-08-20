using Herdr.Windows.Services;

namespace Herdr.Windows.Tests;

public sealed class HerdrConfigServiceTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"herdr-config-{Guid.NewGuid():N}");

    [Fact]
    public void AddsThemeSectionWithoutChangingExistingModules()
    {
        const string original = "[workspace]\nroot = \"C:\\\\code\"\n";

        var result = HerdrConfigService.UpdateThemeContent(original, "tokyo-night");

        Assert.Contains("[workspace]\nroot = \"C:\\\\code\"", result);
        Assert.Contains("[theme]\nname = \"tokyo-night\"\nauto_switch = false\n", result);
    }

    [Fact]
    public void UpdatesOnlyTheOfficialThemeKeys()
    {
        const string original = "[theme]\n# keep this comment\nname = \"nord\" # old\nauto_switch = true\ndark_name = \"dracula\"\n\n[agents]\ngrouped = true\n";

        var result = HerdrConfigService.UpdateThemeContent(original, "rose-pine");

        Assert.Contains("# keep this comment", result);
        Assert.Contains("name = \"rose-pine\"", result);
        Assert.Contains("auto_switch = false", result);
        Assert.Contains("dark_name = \"dracula\"", result);
        Assert.Contains("[agents]\ngrouped = true", result);
    }

    [Fact]
    public void SavesAtomicallyAndLoadsSelectedTheme()
    {
        var path = Path.Combine(_root, "herdr", "config.toml");
        var service = new HerdrConfigService(path);

        service.SaveTheme("catppuccin-latte");

        Assert.Equal("catppuccin-latte", service.LoadThemeName());
        Assert.False(File.Exists(path + ".tmp"));
    }

    public void Dispose()
    {
        if (Directory.Exists(_root)) Directory.Delete(_root, true);
    }
}
