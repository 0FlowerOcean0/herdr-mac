[CmdletBinding()]
param(
    [string]$Version = "0.1.0-preview.2",
    [string]$Configuration = "Release",
    [string]$OutputDirectory = "$PSScriptRoot\..\artifacts"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$terminalRoot = Join-Path $PSScriptRoot "terminal-web"
$publishDirectory = Join-Path $OutputDirectory "Herdr-for-Windows"
$testHostDirectory = Join-Path $OutputDirectory "ConPtyTestHost"
$archivePath = Join-Path $OutputDirectory "Herdr-for-Windows-$Version-x64.zip"
$installerPath = Join-Path $OutputDirectory "Herdr-for-Windows-$Version-x64-Setup.exe"
$installerScript = Join-Path $PSScriptRoot "installer\Herdr.Windows.iss"

function Write-Sha256File([string]$Path) {
    $digest = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumLine = "$digest  $([System.IO.Path]::GetFileName($Path))`n"
    [System.IO.File]::WriteAllText("$Path.sha256", $checksumLine, [System.Text.Encoding]::ASCII)
}

Push-Location $terminalRoot
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE." }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "The terminal asset build failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}

dotnet publish (Join-Path $PSScriptRoot "Herdr.Windows.TestHost\Herdr.Windows.TestHost.csproj") `
    --configuration $Configuration `
    --runtime win-x64 `
    --self-contained false `
    -p:Platform=x64 `
    --output $testHostDirectory
if ($LASTEXITCODE -ne 0) { throw "The ConPTY test host failed to publish with exit code $LASTEXITCODE." }
$env:HERDR_CONPTY_TEST_HOST = Join-Path $testHostDirectory "Herdr.Windows.TestHost.exe"

dotnet run `
    --project (Join-Path $PSScriptRoot "Herdr.Windows.ConPtySmoke\Herdr.Windows.ConPtySmoke.csproj") `
    --configuration $Configuration `
    --runtime win-x64 `
    -- `
    $env:HERDR_CONPTY_TEST_HOST
if ($LASTEXITCODE -ne 0) { throw "The standalone ConPTY smoke test failed with exit code $LASTEXITCODE." }

dotnet test (Join-Path $PSScriptRoot "Herdr.Windows.Tests\Herdr.Windows.Tests.csproj") `
    --configuration $Configuration `
    --runtime win-x64 `
    -p:Platform=x64
if ($LASTEXITCODE -ne 0) { throw "Windows tests failed with exit code $LASTEXITCODE." }

if (Test-Path -LiteralPath $publishDirectory) {
    Remove-Item -LiteralPath $publishDirectory -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $publishDirectory | Out-Null

dotnet publish (Join-Path $PSScriptRoot "Herdr.Windows\Herdr.Windows.csproj") `
    --configuration $Configuration `
    --runtime win-x64 `
    --self-contained true `
    -p:Platform=x64 `
    -p:Version=$Version `
    --output $publishDirectory
if ($LASTEXITCODE -ne 0) { throw "Windows publish failed with exit code $LASTEXITCODE." }

Copy-Item -LiteralPath (Join-Path $repositoryRoot "LICENSE") -Destination $publishDirectory
Copy-Item -LiteralPath (Join-Path $repositoryRoot "THIRD_PARTY_NOTICES.md") -Destination $publishDirectory
Copy-Item -LiteralPath (Join-Path $PSScriptRoot "README-WINDOWS.md") -Destination $publishDirectory

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
Compress-Archive -Path (Join-Path $publishDirectory "*") -DestinationPath $archivePath -CompressionLevel Optimal
Write-Sha256File $archivePath

$innoSetupDirectory = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::ProgramFilesX86)) "Inno Setup 6"
$innoCompiler = Join-Path $innoSetupDirectory "ISCC.exe"
if (-not (Test-Path -LiteralPath $innoCompiler)) {
    $innoCommand = Get-Command "ISCC.exe" -ErrorAction SilentlyContinue
    if ($null -eq $innoCommand) {
        throw "Inno Setup 6 is required to build the Windows installer."
    }
    $innoCompiler = $innoCommand.Source
}

& $innoCompiler `
    "/DMyAppVersion=$Version" `
    "/DPublishDirectory=$publishDirectory" `
    "/DInstallerOutputDirectory=$OutputDirectory" `
    $installerScript
if ($LASTEXITCODE -ne 0) { throw "Inno Setup failed with exit code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $installerPath)) { throw "The Windows installer was not created at $installerPath." }
Write-Sha256File $installerPath

Write-Host "Created $archivePath"
Write-Host "Created $installerPath"
