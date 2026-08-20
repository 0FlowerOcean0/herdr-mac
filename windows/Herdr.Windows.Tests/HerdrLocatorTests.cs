using Herdr.Windows.Services;

namespace Herdr.Windows.Tests;

public sealed class HerdrLocatorTests : IDisposable
{
    private readonly string _root = Path.Combine(Path.GetTempPath(), $"herdr-locator-{Guid.NewGuid():N}");

    [Fact]
    public void FindsTheOfficialInstallerLocation()
    {
        var executable = Path.Combine(_root, "local", "Programs", "Herdr", "bin", "herdr.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(executable)!);
        File.WriteAllText(executable, string.Empty);

        var result = HerdrLocator.Find(
            environment: new Dictionary<string, string?>(),
            localAppData: Path.Combine(_root, "local"),
            userProfile: Path.Combine(_root, "user"));

        Assert.Equal(executable, result, ignoreCase: true);
    }

    [Fact]
    public void ConfiguredExecutableHasPriorityOverPath()
    {
        var configured = CreateExecutable("configured");
        var pathExecutable = CreateExecutable(Path.Combine("path", "herdr.exe"));
        var environment = new Dictionary<string, string?> { ["PATH"] = Path.GetDirectoryName(pathExecutable) };

        var result = HerdrLocator.Find(configured, environment, Path.Combine(_root, "local"), Path.Combine(_root, "user"));

        Assert.Equal(configured, result, ignoreCase: true);
    }

    [Fact]
    public void ReturnsNullWhenNoExecutableExists()
    {
        var result = HerdrLocator.Find(
            environment: new Dictionary<string, string?> { ["PATH"] = Path.Combine(_root, "missing") },
            localAppData: Path.Combine(_root, "local"),
            userProfile: Path.Combine(_root, "user"));

        Assert.Null(result);
    }

    private string CreateExecutable(string relativePath)
    {
        var path = relativePath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)
            ? Path.Combine(_root, relativePath)
            : Path.Combine(_root, relativePath, "herdr.exe");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, string.Empty);
        return path;
    }

    public void Dispose()
    {
        if (Directory.Exists(_root)) Directory.Delete(_root, true);
    }
}
