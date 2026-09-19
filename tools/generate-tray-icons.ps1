<#
Generates the skin-independent tray LED icon set for assets/tray/<type>/.

12 icons: 3 colors (green/blue/red) x 2 sources (disk/net) x 2 states (off/on).
Colors are a fixed procedural gradient (not derived from any skin's own art),
so this script is the only source of truth -- rerun it to regenerate or retune.
Each icon is a multi-size .ico (16/32/48) with PNG-compressed frames, matching
the format of the per-skin TrayOff/On.ico files it replaces.

Usage: pwsh -File tools/generate-tray-icons.ps1 [-OutDir assets/tray] [-PreviewDir <dir>]
#>
param(
  [string]$OutDir = (Join-Path $PSScriptRoot '..\assets\tray'),
  [string]$PreviewDir = ''
)

Add-Type -AssemblyName System.Drawing

$MasterSize = 256
# Covers SM_CXSMICON at the common Windows scale factors: 16=100%, 20=125%,
# 24=150%, 28=175%, 32=200%, 40=250%, 48=300%. Without a frame at the exact
# size TAssetStore.LoadIconFile requests (GetSystemMetrics(SM_CXSMICON) via
# LoadImage, LIM_SMALL), Windows stretches the nearest one and the tray icon
# looks visibly soft at every scale except 100/200/300%.
# 64/96 additionally cover SM_CXICON (LIM_LARGE) at 200%/300% -- used by
# uOptionsForm.pas's LoadLedPreviewIcons for the Tray LED color swatches, which
# deliberately asks for LIM_LARGE rather than LIM_SMALL (see that function's
# comment). LIM_LARGE at 100/125/150% already lands on 32/40/48 above.
$Sizes = @(16, 20, 24, 28, 32, 40, 48, 64, 96)

function New-Color([int]$r, [int]$g, [int]$b, [int]$a = 255) {
  [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

# Off/on core+edge sampled/designed to match the existing per-skin LED look
# (radial gradient sphere, dark ring). On is pushed bright for a strong glow;
# Red's Off is kept very dark so an idle LED does not read as a warning.
$Palette = @{
  green = @{
    OffCore = New-Color 30 79 38;    OffEdge = New-Color 10 26 14
    OnCore  = New-Color 184 255 202; OnEdge  = New-Color 6 228 80
  }
  blue = @{
    OffCore = New-Color 21 73 84;    OffEdge = New-Color 7 26 30
    OnCore  = New-Color 184 255 255; OnEdge  = New-Color 6 187 228
  }
  red = @{
    OffCore = New-Color 37 12 9;     OffEdge = New-Color 12 4 3
    OnCore  = New-Color 255 213 184; OnEdge  = New-Color 223 42 6
  }
}
$RingColor = New-Color 18 18 18
$HighlightColor = New-Color 255 255 255 245
$BezelBright = New-Color 250 250 252
$BezelDark = New-Color 110 112 116

# Fills one or more ellipses (a single circle, or two forming a ring under
# Alternate fill mode) with a radial PathGradientBrush, then disposes both
# the path and the brush. Shared by the bezel ring, the orb core, and the
# highlight below -- all three are "gradient-filled ellipse(s)", differing
# only in shape, colors, optional off-center CenterPoint, and optional bell
# falloff for a stronger "lit up" look.
function Fill-RadialGradientEllipse {
  param($Gfx, [System.Drawing.RectangleF[]]$Ellipses, $CenterColor, $SurroundColor,
        $CenterPoint = $null, [double]$SigmaFalloff = 0)

  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  if ($Ellipses.Count -gt 1) { $path.FillMode = [System.Drawing.Drawing2D.FillMode]::Alternate }
  foreach ($r in $Ellipses) { $path.AddEllipse($r) }
  $grad = [System.Drawing.Drawing2D.PathGradientBrush]::new($path)
  $grad.CenterColor = $CenterColor
  $grad.SurroundColors = @($SurroundColor)
  if ($null -ne $CenterPoint) { $grad.CenterPoint = $CenterPoint }
  if ($SigmaFalloff -gt 0) { $grad.SetSigmaBellShape($SigmaFalloff, 1.0) }
  $Gfx.FillPath($grad, $path)
  $grad.Dispose()
  $path.Dispose()
}

function Draw-Orb {
  param($Gfx, [float]$Cx, [float]$Cy, [float]$D, $CoreColor, $EdgeColor, [bool]$On)

  $ringT = $D * 0.045
  $outer = [System.Drawing.RectangleF]::new(($Cx - $D/2), ($Cy - $D/2), $D, $D)
  $ringBrush = [System.Drawing.SolidBrush]::new($RingColor)
  $Gfx.FillEllipse($ringBrush, $outer)
  $ringBrush.Dispose()

  # A thin chrome-like bezel between the black outer ring and the sphere
  # (matching the per-skin TrayOn/Off.ico look from before the 3.2.0
  # skin-independent generator replaced them).
  $afterRingD = $D - 2 * $ringT
  $bezelT = $D * 0.035
  $bezelInnerD = $afterRingD - 2 * $bezelT
  $bezelOuterRect = [System.Drawing.RectangleF]::new(($Cx - $afterRingD/2), ($Cy - $afterRingD/2), $afterRingD, $afterRingD)
  $bezelInnerRect = [System.Drawing.RectangleF]::new(($Cx - $bezelInnerD/2), ($Cy - $bezelInnerD/2), $bezelInnerD, $bezelInnerD)
  Fill-RadialGradientEllipse -Gfx $Gfx -Ellipses @($bezelOuterRect, $bezelInnerRect) `
    -CenterColor $BezelBright -SurroundColor $BezelDark `
    -CenterPoint ([System.Drawing.PointF]::new($Cx, ($Cy - $afterRingD * 0.30)))

  $innerD = $bezelInnerD
  $innerRect = [System.Drawing.RectangleF]::new(($Cx - $innerD/2), ($Cy - $innerD/2), $innerD, $innerD)
  $sigma = if ($On) { 0.55 } else { 0 }
  Fill-RadialGradientEllipse -Gfx $Gfx -Ellipses @($innerRect) `
    -CenterColor $CoreColor -SurroundColor $EdgeColor `
    -CenterPoint ([System.Drawing.PointF]::new(($Cx - $innerD*0.16), ($Cy - $innerD*0.16))) -SigmaFalloff $sigma

  if ($On) {
    $hlW = $innerD * 0.40; $hlH = $innerD * 0.24
    $hlCx = $Cx - $innerD * 0.20; $hlCy = $Cy - $innerD * 0.22
    $hlRect = [System.Drawing.RectangleF]::new(($hlCx - $hlW/2), ($hlCy - $hlH/2), $hlW, $hlH)
    Fill-RadialGradientEllipse -Gfx $Gfx -Ellipses @($hlRect) `
      -CenterColor $HighlightColor -SurroundColor ([System.Drawing.Color]::FromArgb(0, $HighlightColor))
  }

  return $innerD
}

function Draw-Glyph {
  param($Gfx, [float]$Cx, [float]$Cy, [float]$InnerD, [string]$Glyph, [bool]$On)

  # disk: no glyph -- the plain lit/unlit sphere is the whole story.
  if ($Glyph -eq 'disk') { return }

  # net: a standard Wi-Fi style signal mark -- base dot + three rising arcs,
  # each spanning ~76 degrees (within the usual 60-90 degree range) centered
  # straight up, instead of the earlier wide two-arc sweep.
  # On: black glyph for contrast against the now-brighter sphere. Off: unchanged pale glyph.
  if ($On) {
    $fillColor = [System.Drawing.Color]::FromArgb(235, 8, 8, 8)
  } else {
    # Half the RGB brightness of the previous pure white (255->128), alpha
    # unchanged -- a dimmer, less attention-grabbing glyph for the idle net icon.
    $fillColor = [System.Drawing.Color]::FromArgb(130, 128, 128, 128)
  }
  $fill = [System.Drawing.SolidBrush]::new($fillColor)

  $baseY = $Cy + $InnerD * 0.19
  $dotD = $InnerD * 0.13
  $Gfx.FillEllipse($fill, ($Cx - $dotD/2), ($baseY - $dotD/2), $dotD, $dotD)

  $arcSpan = 76
  $arcStart = 270 - $arcSpan / 2
  $arcPen = [System.Drawing.Pen]::new($fillColor, [Math]::Max(1.0, $InnerD * 0.065))
  $arcPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $arcPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  foreach ($arcD in @(($InnerD * 0.39), ($InnerD * 0.64), ($InnerD * 0.90))) {
    $rect = [System.Drawing.RectangleF]::new(($Cx - $arcD/2), ($baseY - $arcD/2), $arcD, $arcD)
    $Gfx.DrawArc($arcPen, $rect, $arcStart, $arcSpan)
  }
  $arcPen.Dispose()
  $fill.Dispose()
}

function New-MasterBitmap([string]$ColorKey, [string]$Glyph, [bool]$On) {
  $bmp = [System.Drawing.Bitmap]::new($MasterSize, $MasterSize, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)

  $pal = $Palette[$ColorKey]
  $core = if ($On) { $pal.OnCore } else { $pal.OffCore }
  $edge = if ($On) { $pal.OnEdge } else { $pal.OffEdge }
  $cx = $MasterSize / 2.0; $cy = $MasterSize / 2.0
  $d = $MasterSize * 0.90
  $innerD = Draw-Orb -Gfx $g -Cx $cx -Cy $cy -D $d -CoreColor $core -EdgeColor $edge -On $On
  Draw-Glyph -Gfx $g -Cx $cx -Cy $cy -InnerD $innerD -Glyph $Glyph -On $On

  $g.Dispose()
  return $bmp
}

function Get-ResizedPngBytes([System.Drawing.Bitmap]$SrcBitmap, [int]$Size) {
  $bmp = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.DrawImage($SrcBitmap, 0, 0, $Size, $Size)
  $g.Dispose()
  $ms = [System.IO.MemoryStream]::new()
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  # The comma operator stops PowerShell from unrolling the byte array onto the
  # pipeline (which would silently hand callers a boxed Object[] instead of a
  # Byte[] -- BinaryWriter.Write then resolves to the wrong overload).
  return ,$ms.ToArray()
}

function Write-Ico([string]$Path, [System.Collections.IDictionary]$SizeToPngBytes) {
  $sizes = $SizeToPngBytes.Keys | Sort-Object
  $count = $sizes.Count
  $ms = [System.IO.MemoryStream]::new()
  $bw = [System.IO.BinaryWriter]::new($ms)
  $bw.Write([UInt16]0)
  $bw.Write([UInt16]1)
  $bw.Write([UInt16]$count)
  $dirLen = 6 + 16 * $count
  $offset = $dirLen
  foreach ($s in $sizes) {
    $data = $SizeToPngBytes[$s]
    $wByte = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([Byte]$wByte)
    $bw.Write([Byte]$wByte)
    $bw.Write([Byte]0)
    $bw.Write([Byte]0)
    $bw.Write([UInt16]1)
    $bw.Write([UInt16]32)
    $bw.Write([UInt32]$data.Length)
    $bw.Write([UInt32]$offset)
    $offset += $data.Length
  }
  foreach ($s in $sizes) {
    $bw.Write($SizeToPngBytes[$s])
  }
  $bw.Flush()
  [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
  $bw.Dispose(); $ms.Dispose()
}

$colors = @('green', 'blue', 'red')
$sources = @('disk', 'net')

foreach ($color in $colors) {
  $dir = Join-Path $OutDir $color
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  foreach ($src in $sources) {
    foreach ($state in @('Off', 'On')) {
      $on = ($state -eq 'On')
      $genBmp = New-MasterBitmap -ColorKey $color -Glyph $src -On $on
      $sizeMap = @{}
      foreach ($sz in $Sizes) { $sizeMap[$sz] = Get-ResizedPngBytes -SrcBitmap $genBmp -Size $sz }
      $fileName = "$src$state.ico"
      Write-Ico -Path (Join-Path $dir $fileName) -SizeToPngBytes $sizeMap
      Write-Output "$dir\$fileName"

      if ($PreviewDir -ne '') {
        New-Item -ItemType Directory -Force -Path $PreviewDir | Out-Null
        foreach ($prevSz in @(16, 32, 128)) {
          $prevPath = Join-Path $PreviewDir "$color`_$src$state`_$prevSz.png"
          [System.IO.File]::WriteAllBytes($prevPath, (Get-ResizedPngBytes -SrcBitmap $genBmp -Size $prevSz))
        }
      }
      $genBmp.Dispose()
    }
  }
}
