using System.Text.Json;
using Herdr.Windows.Models;

namespace Herdr.Windows.Services;

public sealed class AppSettingsService
{
    private static readonly JsonSerializerOptions JsonOptions = new() { WriteIndented = true };

    public string SettingsPath { get; }

    public AppSettingsService(string? settingsPath = null)
    {
        SettingsPath = settingsPath ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "HerdrGui",
            "settings.json");
    }

    public AppSettings Load()
    {
        try
        {
            var json = File.ReadAllText(SettingsPath);
            return JsonSerializer.Deserialize<AppSettings>(json) ?? new AppSettings();
        }
        catch (IOException)
        {
            return new AppSettings();
        }
        catch (JsonException)
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        var directory = Path.GetDirectoryName(SettingsPath)
            ?? throw new InvalidOperationException("The settings path has no parent directory.");
        Directory.CreateDirectory(directory);
        var temporaryPath = SettingsPath + ".tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(settings, JsonOptions));
        File.Move(temporaryPath, SettingsPath, true);
    }
}
