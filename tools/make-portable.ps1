# Builds dist/DiskLED-3.0.1-portable.zip from a staged folder.
# Usage: .\tools\make-portable.ps1 [-Config Release|Debug]

param(
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release',
    [string]$Version = '3.1.0'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$StageScript = Join-Path $PSScriptRoot 'stage-dist.ps1'
$Stage = Join-Path $Root 'dist\DiskLED'
$OutZip = Join-Path $Root "dist\DiskLED-$Version-portable.zip"

& $StageScript -Config $Config

if (-not (Test-Path -LiteralPath (Join-Path $Stage 'DiskLED.exe'))) {
    Write-Error "Staging failed — DiskLED.exe missing under $Stage"
}

New-Item -ItemType Directory -Path (Join-Path $Root 'dist') -Force | Out-Null
if (Test-Path -LiteralPath $OutZip) {
    Remove-Item -LiteralPath $OutZip -Force
}

Compress-Archive -Path (Join-Path $Stage '*') -DestinationPath $OutZip -Force
Write-Host "Portable zip: $OutZip"
Write-Host ("Size: {0:N0} bytes" -f (Get-Item -LiteralPath $OutZip).Length)
