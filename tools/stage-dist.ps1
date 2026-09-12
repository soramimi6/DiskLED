# Stages a distributable folder: dist/DiskLED/
# Requires DiskLED.exe under Win64\<Config>\ (default Release).
# Usage: .\tools\stage-dist.ps1 [-Config Release|Debug]

param(
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$ExeSrc = Join-Path $Root "Win64\$Config\DiskLED.exe"
$Stage = Join-Path $Root 'dist\DiskLED'
$Assets = Join-Path $Root 'assets'
$Styles = Join-Path $Root 'styles'
$AssetEditor = Join-Path $Root 'asset-editor'

if (-not (Test-Path -LiteralPath $ExeSrc)) {
    Write-Error @"
DiskLED.exe not found: $ExeSrc

Build Win64/$Config in Delphi IDE (Project > Build), then re-run this script.
Community Edition cannot compile from the command line.
"@
}

if (-not (Test-Path -LiteralPath $Assets)) {
    Write-Error "assets folder missing: $Assets"
}

Write-Host "Staging from: $ExeSrc"
if (Test-Path -LiteralPath $Stage) {
    Remove-Item -LiteralPath $Stage -Recurse -Force
}
New-Item -ItemType Directory -Path $Stage | Out-Null

Copy-Item -LiteralPath $ExeSrc -Destination (Join-Path $Stage 'DiskLED.exe') -Force
Copy-Item -LiteralPath $Assets -Destination (Join-Path $Stage 'assets') -Recurse -Force

$License = Join-Path $Root 'LICENSE.txt'
if (Test-Path -LiteralPath $License) {
    Copy-Item -LiteralPath $License -Destination (Join-Path $Stage 'LICENSE.txt') -Force
} else {
    Write-Warning "LICENSE.txt missing — staged folder will ship without a license file."
}

# Editable source stays at public_docs/ (stage folder is wiped each run).
$PublicDocs = Join-Path $Root 'public_docs'
if (Test-Path -LiteralPath $PublicDocs) {
    Copy-Item -LiteralPath $PublicDocs -Destination (Join-Path $Stage 'public_docs') -Recurse -Force
} else {
    Write-Warning "public_docs missing — staged folder will ship without user documentation."
}

# Drop editor leftovers and image-editing sources — kept in git for future
# edits (assets/**/ImageResource/*.xcf), never shipped to users.
$junk = Get-ChildItem -LiteralPath (Join-Path $Stage 'assets') -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.tmp', '.bak', '.xcf') }
if ($junk) {
    $junk | Remove-Item -Force -ErrorAction SilentlyContinue
}
$imgSrc = Join-Path $Stage 'assets\infobar\ImageResource'
if (Test-Path -LiteralPath $imgSrc) {
    Remove-Item -LiteralPath $imgSrc -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $Styles) {
    Copy-Item -LiteralPath $Styles -Destination (Join-Path $Stage 'styles') -Recurse -Force
} else {
    Write-Warning "styles folder missing — Options dialog may fall back without VCL style."
}

if (Test-Path -LiteralPath $AssetEditor) {
    Copy-Item -LiteralPath $AssetEditor -Destination (Join-Path $Stage 'asset-editor') -Recurse -Force
    # Dev-only Node round-trip check script -- not something an end user
    # needs or can run without Node.js; index.html itself does everything
    # a user-facing double-click tool needs.
    $spikeScript = Join-Path $Stage 'asset-editor\spike-roundtrip.cjs'
    if (Test-Path -LiteralPath $spikeScript) {
        Remove-Item -LiteralPath $spikeScript -Force
    }
} else {
    Write-Warning "asset-editor folder missing — staged folder will ship without the skin editor tool."
}

# Never ship a user ini
$Ini = Join-Path $Stage 'DiskLED.ini'
if (Test-Path -LiteralPath $Ini) {
    Remove-Item -LiteralPath $Ini -Force
}

Write-Host "Staged: $Stage"
Get-ChildItem -LiteralPath $Stage | ForEach-Object { Write-Host ("  {0}" -f $_.Name) }
