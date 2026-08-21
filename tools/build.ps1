# DiskLED build helper (Delphi)
#
# Community Edition cannot compile from the command line (product limitation).
# This script:
#   - detects CE vs paid (dcc64 probe)
#   - on paid editions: runs MSBuild Win64 Debug
#   - on CE: if RAD Studio is running, sends Shift+F9 (Build) to the IDE
#
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File tools\build.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root

$StudioBin = "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin"
$Dcc64 = Join-Path $StudioBin "dcc64.exe"
$Dproj = Join-Path $Root "DiskLED.dproj"

if (-not (Test-Path -LiteralPath $Dproj)) {
  Write-Error "DiskLED.dproj not found: $Dproj"
}

function Test-DelphiCommunityEdition {
  if (-not (Test-Path -LiteralPath $Dcc64)) {
    Write-Warning "dcc64.exe not found; assuming Community Edition restrictions."
    return $true
  }
  $out = & $Dcc64 2>&1 | Out-String
  return ($out -match "does not support command line compiling")
}

function Invoke-IdeBuild {
  $bds = Get-Process -Name "bds" -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $bds) {
    Write-Host ""
    Write-Host "RAD Studio (bds.exe) is not running."
    Write-Host "1. Open DiskLED.dproj in Delphi"
    Write-Host "2. Press F9 (Run) or Shift+F9 (Build)"
    Write-Host "3. If errors appear, paste the Messages text into Cursor"
    return 2
  }

  Add-Type -AssemblyName Microsoft.VisualBasic
  Add-Type -AssemblyName System.Windows.Forms

  try {
    [Microsoft.VisualBasic.Interaction]::AppActivate($bds.Id) | Out-Null
  } catch {
    Write-Warning "Could not activate Delphi window: $_"
    return 3
  }

  Start-Sleep -Milliseconds 400
  # Shift+F9 = Project > Build
  [System.Windows.Forms.SendKeys]::SendWait("+{F9}")
  Write-Host "Sent Shift+F9 to Delphi (Build)."
  Write-Host "Check the Messages pane. Paste any errors into Cursor to continue the fix loop."
  return 0
}

function Invoke-MsBuild {
  $rsvars = Join-Path $StudioBin "rsvars.bat"
  if (-not (Test-Path -LiteralPath $rsvars)) {
    Write-Error "rsvars.bat not found: $rsvars"
  }
  cmd /c "`"$rsvars`" && msbuild `"$Dproj`" /t:Build /p:Config=Debug /p:Platform=Win64 /v:m"
  return $LASTEXITCODE
}

Write-Host "DiskLED build helper"
Write-Host "Project: $Dproj"

if (Test-DelphiCommunityEdition) {
  Write-Host ""
  Write-Host "Detected Delphi Community Edition."
  Write-Host "Command-line compiling is disabled by Embarcadero for CE."
  Write-Host "Falling back to IDE Build shortcut..."
  exit (Invoke-IdeBuild)
}

Write-Host "Paid/CLI-capable Delphi detected. Running MSBuild..."
$code = Invoke-MsBuild
if ($code -ne 0) {
  Write-Host "MSBuild failed with exit code $code"
}
exit $code
