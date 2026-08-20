namespace Herdr.Windows.Services;

public static class HerdrLocator
{
    public static string? Find(
        string? configuredPath = null,
        IReadOnlyDictionary<string, string?>? environment = null,
        string? localAppData = null,
        string? userProfile = null)
    {
        environment ??= Environment.GetEnvironmentVariables()
            .Cast<System.Collections.DictionaryEntry>()
            .ToDictionary(entry => (string)entry.Key, entry => entry.Value?.ToString(), StringComparer.OrdinalIgnoreCase);
        localAppData ??= Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        userProfile ??= Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);

        var candidates = new List<string?>
        {
            configuredPath,
            Value(environment, "HERDR_BIN_PATH"),
            Path.Combine(localAppData, "Programs", "Herdr", "bin", "herdr.exe"),
            Path.Combine(userProfile, ".herdr", "packages", "standalone", "current", "herdr.exe")
        };

        var pathValue = Value(environment, "PATH");
        if (!string.IsNullOrWhiteSpace(pathValue))
        {
            candidates.AddRange(pathValue.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries)
                .Select(directory => Path.Combine(directory.Trim(), "herdr.exe")));
        }

        foreach (var candidate in candidates)
        {
            if (string.IsNullOrWhiteSpace(candidate)) continue;
            try
            {
                var fullPath = Path.GetFullPath(Environment.ExpandEnvironmentVariables(candidate.Trim().Trim('"')));
                if (File.Exists(fullPath)) return fullPath;
            }
            catch (Exception exception) when (exception is ArgumentException or NotSupportedException or PathTooLongException)
            {
                // Ignore malformed PATH entries and continue through the official locations.
            }
        }

        return null;
    }

    private static string? Value(IReadOnlyDictionary<string, string?> values, string name) =>
        values.FirstOrDefault(pair => string.Equals(pair.Key, name, StringComparison.OrdinalIgnoreCase)).Value;
}
