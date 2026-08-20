using System.Diagnostics;
using System.Text;

namespace Herdr.Windows.Services;

public sealed class HerdrConfigService
{
    public string ConfigPath { get; }

    public HerdrConfigService(string? configPath = null)
    {
        ConfigPath = configPath ?? ResolveConfigPath();
    }

    public string? LoadThemeName()
    {
        if (!File.Exists(ConfigPath)) return null;
        var lines = File.ReadAllLines(ConfigPath);
        var range = FindSection(lines, "theme");
        if (range is null) return null;

        for (var index = range.Value.Start; index < range.Value.End; index++)
        {
            if (!TryReadValue(lines[index], "name", out var value)) continue;
            return Unquote(value);
        }

        return null;
    }

    public void SaveTheme(string themeName)
    {
        var content = File.Exists(ConfigPath) ? File.ReadAllText(ConfigPath) : string.Empty;
        var updated = UpdateThemeContent(content, themeName);
        var directory = Path.GetDirectoryName(ConfigPath)
            ?? throw new InvalidOperationException("The Herdr config path has no parent directory.");
        Directory.CreateDirectory(directory);
        var temporaryPath = ConfigPath + ".tmp";
        File.WriteAllText(temporaryPath, updated, new UTF8Encoding(false));
        File.Move(temporaryPath, ConfigPath, true);
    }

    public static string UpdateThemeContent(string content, string themeName)
    {
        if (string.IsNullOrWhiteSpace(themeName)) throw new ArgumentException("A theme name is required.", nameof(themeName));
        var newline = content.Contains("\r\n", StringComparison.Ordinal) ? "\r\n" : "\n";
        var normalized = content.Replace("\r\n", "\n", StringComparison.Ordinal);
        var lines = normalized.Split('\n').ToList();
        if (lines.Count > 0 && lines[^1].Length == 0) lines.RemoveAt(lines.Count - 1);

        var range = FindSection(lines, "theme");
        if (range is null)
        {
            if (lines.Count > 0 && lines[^1].Length > 0) lines.Add(string.Empty);
            lines.Add("[theme]");
            lines.Add($"name = \"{themeName}\"");
            lines.Add("auto_switch = false");
        }
        else
        {
            Upsert(lines, range.Value, "name", $"\"{themeName}\"");
            range = FindSection(lines, "theme");
            Upsert(lines, range!.Value, "auto_switch", "false");
        }

        return string.Join(newline, lines) + newline;
    }

    public static async Task ReloadAsync(string herdrPath, string? sessionName, CancellationToken cancellationToken = default)
    {
        var arguments = new List<string>();
        if (!string.IsNullOrWhiteSpace(sessionName))
        {
            arguments.Add("--session");
            arguments.Add(sessionName.Trim());
        }
        arguments.Add("server");
        arguments.Add("reload-config");

        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = herdrPath,
                WorkingDirectory = Path.GetDirectoryName(herdrPath) ?? Environment.CurrentDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            }
        };
        foreach (var argument in arguments) process.StartInfo.ArgumentList.Add(argument);
        process.Start();
        await process.WaitForExitAsync(cancellationToken);
        if (process.ExitCode != 0)
        {
            var error = await process.StandardError.ReadToEndAsync(cancellationToken);
            throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? "Herdr could not reload its configuration." : error.Trim());
        }
    }

    private static string ResolveConfigPath()
    {
        var explicitPath = Environment.GetEnvironmentVariable("HERDR_CONFIG_PATH");
        if (!string.IsNullOrWhiteSpace(explicitPath)) return explicitPath;
        return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "herdr", "config.toml");
    }

    private static (int Start, int End)? FindSection(IReadOnlyList<string> lines, string section)
    {
        var header = $"[{section}]";
        var headerIndex = -1;
        for (var index = 0; index < lines.Count; index++)
        {
            if (string.Equals(lines[index].Trim(), header, StringComparison.Ordinal))
            {
                headerIndex = index;
                break;
            }
        }
        if (headerIndex < 0) return null;

        var end = lines.Count;
        for (var index = headerIndex + 1; index < lines.Count; index++)
        {
            var value = lines[index].Trim();
            if (value.StartsWith("[", StringComparison.Ordinal) && value.EndsWith("]", StringComparison.Ordinal))
            {
                end = index;
                break;
            }
        }
        return (headerIndex + 1, end);
    }

    private static void Upsert(List<string> lines, (int Start, int End) range, string key, string value)
    {
        for (var index = range.Start; index < range.End; index++)
        {
            if (!TryReadValue(lines[index], key, out _)) continue;
            lines[index] = $"{key} = {value}";
            return;
        }
        lines.Insert(range.Start, $"{key} = {value}");
    }

    private static bool TryReadValue(string line, string key, out string value)
    {
        value = string.Empty;
        var trimmed = line.Trim();
        if (trimmed.StartsWith('#')) return false;
        var equals = trimmed.IndexOf('=');
        if (equals < 0 || !string.Equals(trimmed[..equals].Trim(), key, StringComparison.Ordinal)) return false;
        value = StripComment(trimmed[(equals + 1)..].Trim());
        return true;
    }

    private static string StripComment(string value)
    {
        var quote = '\0';
        for (var index = 0; index < value.Length; index++)
        {
            var character = value[index];
            if (quote == '\0' && (character == '\"' || character == '\'')) quote = character;
            else if (quote == character) quote = '\0';
            else if (quote == '\0' && character == '#') return value[..index].Trim();
        }
        return value;
    }

    private static string? Unquote(string value)
    {
        var trimmed = value.Trim();
        if (trimmed.Length >= 2 && ((trimmed[0] == '\"' && trimmed[^1] == '\"') || (trimmed[0] == '\'' && trimmed[^1] == '\'')))
        {
            trimmed = trimmed[1..^1];
        }
        return trimmed.Length == 0 ? null : trimmed;
    }
}
