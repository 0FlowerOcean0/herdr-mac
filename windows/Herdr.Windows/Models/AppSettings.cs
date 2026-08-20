namespace Herdr.Windows.Models;

public sealed class AppSettings
{
    public string? HerdrPath { get; set; }
    public string? WorkingDirectory { get; set; }
    public string? SessionName { get; set; }
    public string ThemeName { get; set; } = "catppuccin";
}
