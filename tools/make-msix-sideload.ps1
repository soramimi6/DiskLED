# Builds and locally signs an MSIX for SIDELOAD TESTING (not Store submission).
#
# The Store submission uses an UNSIGNED .msix that Microsoft signs. Local
# sideloading instead needs the package signed by a certificate whose subject
# exactly matches <Identity Publisher> in the manifest, with that certificate
# trusted on this machine. This script does all of that.
#
# Usage:
#   .\tools\make-msix-sideload.ps1 [-Config Release|Debug] [-Install]
#
#   -Install   after building, (re)install the package for the current user
#
# Requires: Win64\<Config>\DiskLED.exe already built in the RAD Studio IDE,
#           Windows SDK (makeappx.exe / signtool.exe).
# Importing the test certificate into LocalMachine\TrustedPeople needs an
# elevated shell the first time; the script prints the exact command if it
# cannot do it itself.

param(
    [ValidateSet('Release', 'Debug')]
    [string]$Config = 'Release',
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$StageScript = Join-Path $PSScriptRoot 'stage-dist.ps1'
$Stage = Join-Path $Root 'dist\DiskLED'
$Manifest = Join-Path $Root 'packaging\msix\AppxManifest.xml'
$PackageAssets = Join-Path $Root 'packaging\msix\PackageAssets'
$Layout = Join-Path $Root 'dist\msix\layout'
$MsixDir = Join-Path $Root 'dist\msix'

function Find-SdkTool([string]$name) {
    $bin = 'C:\Program Files (x86)\Windows Kits\10\bin'
    if (-not (Test-Path -LiteralPath $bin)) { return $null }
    Get-ChildItem -LiteralPath $bin -Directory |
        Where-Object { $_.Name -match '^10\.' } |
        Sort-Object Name -Descending |
        ForEach-Object {
            $p = Join-Path $_.FullName "x64\$name"
            if (Test-Path -LiteralPath $p) { return $p }
        } | Select-Object -First 1
}

$MakeAppx = Find-SdkTool 'makeappx.exe'
$SignTool = Find-SdkTool 'signtool.exe'
if (-not $MakeAppx) { Write-Error 'makeappx.exe not found. Install the Windows 10/11 SDK.' }
if (-not $SignTool) { Write-Error 'signtool.exe not found. Install the Windows 10/11 SDK.' }
if (-not (Test-Path -LiteralPath $Manifest)) { Write-Error "Manifest missing: $Manifest" }

# --- read Identity from the manifest ---
[xml]$mx = Get-Content -LiteralPath $Manifest -Raw
$publisher = $mx.Package.Identity.Publisher
$version = $mx.Package.Identity.Version
$idName = $mx.Package.Identity.Name
Write-Host "Manifest: $idName  $version"
Write-Host "Publisher (cert subject must match): $publisher"

# --- stage the payload ---
& $StageScript -Config $Config
if (-not (Test-Path -LiteralPath (Join-Path $Stage 'DiskLED.exe'))) {
    Write-Error "Staging failed - DiskLED.exe missing under $Stage"
}

# --- assemble the pack layout ---
if (Test-Path -LiteralPath $Layout) { Remove-Item -LiteralPath $Layout -Recurse -Force }
New-Item -ItemType Directory -Path $Layout | Out-Null
foreach ($item in 'DiskLED.exe', 'LICENSE.txt', 'assets', 'styles', 'public_docs') {
    $src = Join-Path $Stage $item
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $Layout $item) -Recurse -Force
    }
}
Copy-Item -LiteralPath $PackageAssets -Destination (Join-Path $Layout 'PackageAssets') -Recurse -Force
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Layout 'AppxManifest.xml') -Force

# --- pack ---
$Msix = Join-Path $MsixDir ("DiskLED_{0}_x64_sideload.msix" -f $version)
if (Test-Path -LiteralPath $Msix) { Remove-Item -LiteralPath $Msix -Force }
& $MakeAppx pack /o /d $Layout /p $Msix
if ($LASTEXITCODE -ne 0) { Write-Error "makeappx failed ($LASTEXITCODE)" }

# --- test-signing certificate (subject == manifest Publisher) ---
$cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq $publisher -and $_.HasPrivateKey } |
    Sort-Object NotAfter -Descending | Select-Object -First 1
if (-not $cert) {
    Write-Host "Creating self-signed test certificate for $publisher ..."
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $publisher `
        -CertStoreLocation Cert:\CurrentUser\My -KeyExportPolicy Exportable `
        -KeyUsage DigitalSignature -FriendlyName 'DiskLED MSIX sideload test' `
        -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3')
}
Write-Host ("Certificate thumbprint: {0}" -f $cert.Thumbprint)

# --- make sure the cert is trusted for package deployment ---
$trusted = Get-ChildItem Cert:\LocalMachine\TrustedPeople -ErrorAction SilentlyContinue |
    Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
if (-not $trusted) {
    $cerPath = Join-Path $MsixDir 'DiskLED-sideload-test.cer'
    Export-Certificate -Cert $cert -FilePath $cerPath -Force | Out-Null
    try {
        Import-Certificate -FilePath $cerPath -CertStoreLocation Cert:\LocalMachine\TrustedPeople -ErrorAction Stop | Out-Null
        Write-Host 'Imported test certificate into LocalMachine\TrustedPeople.'
    } catch {
        Write-Warning @"
Could not import the test certificate (needs an elevated shell).
Run this once in an ADMIN PowerShell, then re-run this script:

  Import-Certificate -FilePath '$cerPath' -CertStoreLocation Cert:\LocalMachine\TrustedPeople
"@
    }
}

# --- sign ---
& $SignTool sign /fd SHA256 /sha1 $cert.Thumbprint $Msix
if ($LASTEXITCODE -ne 0) { Write-Error "signtool failed ($LASTEXITCODE)" }

Write-Host ''
Write-Host "Signed sideload package: $Msix"
Write-Host ("Size: {0:N0} bytes" -f (Get-Item -LiteralPath $Msix).Length)

if ($Install) {
    Write-Host 'Installing for current user (in-place update, keeps app + startup-task state) ...'
    try {
        Add-AppxPackage -Path $Msix -ForceApplicationShutdown -ForceUpdateFromAnyVersion -ErrorAction Stop
    } catch {
        Write-Warning "In-place update failed ($_). Removing and reinstalling (this resets the startup-task consent) ..."
        Get-AppxPackage -Name $idName | Where-Object { $_.IsFramework -eq $false } |
            ForEach-Object { Remove-AppxPackage -Package $_.PackageFullName -ErrorAction SilentlyContinue }
        Add-AppxPackage -Path $Msix
    }
    Write-Host 'Installed. Launch DiskLED from the Start menu.'
} else {
    Write-Host ''
    Write-Host ("To install:  Add-AppxPackage -Path `"{0}`"" -f $Msix)
    Write-Host '   or:       double-click the .msix (App Installer)'
    Write-Host 'To remove:   Get-AppxPackage *DiskLED* | Remove-AppxPackage'
}
