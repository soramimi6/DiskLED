# Stages dist and compiles the Inno Setup installer.
# Usage: .\tools\make-installer.ps1 [-Config Release|Debug]
# Requires Inno Setup 6 (ISCC.exe).

param(
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release',
    [string]$Version = '3.0.1'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$StageScript = Join-Path $PSScriptRoot 'stage-dist.ps1'
$Iss = Join-Path $Root 'installer\DiskLED.iss'
$OutExe = Join-Path $Root "dist\DiskLED_Setup_$Version.exe"

function Find-ISCC {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
        "${env:LocalAppData}\Programs\Inno Setup 6\ISCC.exe"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            return $c
        }
    }
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

$Iscc = Find-ISCC
if (-not $Iscc) {
    Write-Error @"
Inno Setup 6 (ISCC.exe) not found.

Install from https://jrsoftware.org/isinfo.php
Then re-run: .\tools\make-installer.ps1
"@
}

if (-not (Test-Path -LiteralPath $Iss)) {
    Write-Error "Missing script: $Iss"
}

& $StageScript -Config $Config

Write-Host "Compiling with: $Iscc"
& $Iscc $Iss
if ($LASTEXITCODE -ne 0) {
    Write-Error "ISCC failed with exit code $LASTEXITCODE"
}

if (-not (Test-Path -LiteralPath $OutExe)) {
    Write-Error "Expected output missing: $OutExe"
}

Write-Host "Installer: $OutExe"
Write-Host ("Size: {0:N0} bytes" -f (Get-Item -LiteralPath $OutExe).Length)
