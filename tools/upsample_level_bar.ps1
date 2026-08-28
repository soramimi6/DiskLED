# Upsample Crystal-style left-to-right level bar strips by compositing empty/full frames.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [Parameter(Mandatory = $true)][int]$OrigFrames,
  [int]$NewFrames = 32
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$im = [System.Drawing.Bitmap]::FromFile($Source)
$fw = $im.Width
$fh = [int]($im.Height / $OrigFrames)
if ($fh * $OrigFrames -ne $im.Height) {
  throw "Height $($im.Height) is not divisible by $OrigFrames frames"
}

function Copy-Frame([System.Drawing.Bitmap]$Src, [int]$SrcFrame, [System.Drawing.Bitmap]$Dst, [int]$DstFrame, [int]$W, [int]$H) {
  for ($y = 0; $y -lt $H; $y++) {
    for ($x = 0; $x -lt $W; $x++) {
      $Dst.SetPixel($x, $DstFrame * $H + $y, $Src.GetPixel($x, $SrcFrame * $H + $y))
    }
  }
}

# Cache empty (0) and full (last) frame pixels
$emptyR = New-Object 'int[]' ($fw * $fh)
$emptyG = New-Object 'int[]' ($fw * $fh)
$emptyB = New-Object 'int[]' ($fw * $fh)
$fullR = New-Object 'int[]' ($fw * $fh)
$fullG = New-Object 'int[]' ($fw * $fh)
$fullB = New-Object 'int[]' ($fw * $fh)
$last = $OrigFrames - 1
for ($y = 0; $y -lt $fh; $y++) {
  for ($x = 0; $x -lt $fw; $x++) {
    $i = $y * $fw + $x
    $e = $im.GetPixel($x, $y)
    $f = $im.GetPixel($x, $last * $fh + $y)
    $emptyR[$i] = $e.R; $emptyG[$i] = $e.G; $emptyB[$i] = $e.B
    $fullR[$i] = $f.R; $fullG[$i] = $f.G; $fullB[$i] = $f.B
  }
}

$out = New-Object System.Drawing.Bitmap $fw, ($fh * $NewFrames), ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
for ($nf = 0; $nf -lt $NewFrames; $nf++) {
  # Continuous fill edge in [0, fw]; 0 = empty, fw = completely full
  $edge = ($nf / [double]($NewFrames - 1)) * $fw
  for ($y = 0; $y -lt $fh; $y++) {
    for ($x = 0; $x -lt $fw; $x++) {
      $i = $y * $fw + $x
      # Soft 1px transition at the fill edge
      $a = $edge - $x  # >1 full, <0 empty, 0..1 blend
      if ($a -ge 1.0) {
        $r = $fullR[$i]; $g = $fullG[$i]; $b = $fullB[$i]
      }
      elseif ($a -le 0.0) {
        $r = $emptyR[$i]; $g = $emptyG[$i]; $b = $emptyB[$i]
      }
      else {
        $r = [int][Math]::Round($emptyR[$i] * (1.0 - $a) + $fullR[$i] * $a)
        $g = [int][Math]::Round($emptyG[$i] * (1.0 - $a) + $fullG[$i] * $a)
        $b = [int][Math]::Round($emptyB[$i] * (1.0 - $a) + $fullB[$i] * $a)
      }
      if ($r -lt 0) { $r = 0 }; if ($r -gt 255) { $r = 255 }
      if ($g -lt 0) { $g = 0 }; if ($g -gt 255) { $g = 255 }
      if ($b -lt 0) { $b = 0 }; if ($b -gt 255) { $b = 255 }
      $out.SetPixel($x, $nf * $fh + $y, [System.Drawing.Color]::FromArgb($r, $g, $b))
    }
  }
}

$destDir = Split-Path -Parent $Dest
if ($destDir -and -not (Test-Path $destDir)) {
  New-Item -ItemType Directory -Path $destDir | Out-Null
}
if (Test-Path -LiteralPath $Dest) {
  Remove-Item -LiteralPath $Dest -Force
}
$out.Save($Dest, [System.Drawing.Imaging.ImageFormat]::Bmp)
Write-Host ("Saved {0} ({1}x{2}, {3} frames from {4})" -f $Dest, $out.Width, $out.Height, $NewFrames, $OrigFrames)
$out.Dispose()
$im.Dispose()
