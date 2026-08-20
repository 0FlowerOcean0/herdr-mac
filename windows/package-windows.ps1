[CmdletBinding()]
param(
    [string]$Version = "0.1.0-preview.1",
    [string]$Configuration = "Release",
    [string]$OutputDirectory = "$PSScriptRoot\..\artifacts"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$terminalRoot = Join-Path $PSScriptRoot "terminal-web"
$publishDirectory = Join-Path $OutputDirectory "Herdr-for-Windows"
$archivePath = Join-Path $OutputDirectory "Herdr-for-Windows-$Version-x64.zip"

Push-Location $terminalRoot
try {
    npm ci
    if ($LASTEXITCODE -ne 0) { throw "npm ci failed with exit code $LASTEXITCODE." }
    npm run build
    if ($LASTEXITCODE -ne 0) { throw "The terminal asset build failed with exit code $LASTEXITCODE." }
} finally {
    Pop-Location
}

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
$digest = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$archivePath.sha256" -Value "$digest  $([System.IO.Path]::GetFileName($archivePath))" -Encoding ascii
Write-Host "Created $archivePath"
