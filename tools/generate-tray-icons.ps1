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
$Sizes = @(16, 32, 48)

function New-Color([int]$r, [int]$g, [int]$b, [int]$a = 255) {
  [System.Drawing.Color]::FromArgb($a, $r, $g, $b)
}

# Off/on core+edge sampled/designed to match the existing per-skin LED look
# (radial gradient sphere, dark ring). On is pushed bright for a strong glow;
# Red's Off is kept very dark so an idle LED does not read as a warning.
$Palette = @{
  green = @{
    OffCore = New-Color 39 70 44;    OffEdge = New-Color 18 32 21
    OnCore  = New-Color 224 255 232; OnEdge  = New-Color 95 230 140
  }
  blue = @{
    OffCore = New-Color 33 65 72;    OffEdge = New-Color 16 32 36
    OnCore  = New-Color 218 255 255; OnEdge  = New-Color 80 215 245
  }
  red = @{
    OffCore = New-Color 32 16 14;    OffEdge = New-Color 14 7 6
    OnCore  = New-Color 255 220 195; OnEdge  = New-Color 240 105 78
  }
}
$RingColor = New-Color 18 18 18
$HighlightColor = New-Color 255 255 255 245

function Draw-Orb {
  param($Gfx, [float]$Cx, [float]$Cy, [float]$D, $CoreColor, $EdgeColor, [bool]$On)

  $ringT = $D * 0.045
  $outer = [System.Drawing.RectangleF]::new(($Cx - $D/2), ($Cy - $D/2), $D, $D)
  $ringBrush = [System.Drawing.SolidBrush]::new($RingColor)
  $Gfx.FillEllipse($ringBrush, $outer)
  $ringBrush.Dispose()

  $innerD = $D - 2 * $ringT
  $innerRect = [System.Drawing.RectangleF]::new(($Cx - $innerD/2), ($Cy - $innerD/2), $innerD, $innerD)
  $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $path.AddEllipse($innerRect)
  $grad = [System.Drawing.Drawing2D.PathGradientBrush]::new($path)
  $grad.CenterColor = $CoreColor
  $grad.SurroundColors = @($EdgeColor)
  $grad.CenterPoint = [System.Drawing.PointF]::new(($Cx - $innerD*0.16), ($Cy - $innerD*0.16))
  if ($On) {
    # A bell falloff keeps the bright core color over more of the sphere
    # instead of a linear falloff, i.e. a stronger "lit up" look.
    $grad.SetSigmaBellShape(0.55, 1.0)
  }
  $Gfx.FillPath($grad, $path)
  $grad.Dispose()
  $path.Dispose()

  if ($On) {
    $hlW = $innerD * 0.40; $hlH = $innerD * 0.24
    $hlCx = $Cx - $innerD * 0.20; $hlCy = $Cy - $innerD * 0.22
    $hlRect = [System.Drawing.RectangleF]::new(($hlCx - $hlW/2), ($hlCy - $hlH/2), $hlW, $hlH)
    $hlPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $hlPath.AddEllipse($hlRect)
    $hlGrad = [System.Drawing.Drawing2D.PathGradientBrush]::new($hlPath)
    $hlGrad.CenterColor = $HighlightColor
    $hlGrad.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $HighlightColor))
    $Gfx.FillPath($hlGrad, $hlPath)
    $hlGrad.Dispose()
    $hlPath.Dispose()
  }

  return $innerD
}

function Draw-Glyph {
  param($Gfx, [float]$Cx, [float]$Cy, [float]$InnerD, [string]$Glyph, [bool]$On)

  # On: black glyph for contrast against the now-brighter sphere. Off: unchanged pale glyph.
  if ($On) {
    $fillColor = [System.Drawing.Color]::FromArgb(235, 8, 8, 8)
    $strokeColor = [System.Drawing.Color]::FromArgb(200, 0, 0, 0)
  } else {
    $fillColor = [System.Drawing.Color]::FromArgb(130, 255, 255, 255)
    $strokeColor = [System.Drawing.Color]::FromArgb(90, 10, 10, 10)
  }
  $fill = [System.Drawing.SolidBrush]::new($fillColor)
  $stroke = [System.Drawing.Pen]::new($strokeColor, [Math]::Max(1.0, $InnerD * 0.02))
  $stroke.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round

  if ($Glyph -eq 'disk') {
    $barW = $InnerD * 0.56; $barH = $InnerD * 0.13; $gap = $InnerD * 0.14
    foreach ($dy in @(-($gap/2 + $barH/2), ($gap/2 + $barH/2))) {
      $r = [System.Drawing.RectangleF]::new(($Cx - $barW/2), ($Cy + $dy - $barH/2), $barW, $barH)
      $rad = $barH / 2
      $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
      $path.AddArc($r.X, $r.Y, $barH, $barH, 90, 180)
      $path.AddArc(($r.X + $r.Width - $barH), $r.Y, $barH, $barH, 270, 180)
      $path.CloseFigure()
      $Gfx.FillPath($fill, $path)
      $Gfx.DrawPath($stroke, $path)
      $path.Dispose()
    }
  } else {
    $triW = $InnerD * 0.5; $triH = $InnerD * 0.30; $gap = $InnerD * 0.08
    # Up triangle (top half)
    $topCy = $Cy - $gap/2 - $triH/2
    $up = @(
      [System.Drawing.PointF]::new($Cx, ($topCy - $triH/2)),
      [System.Drawing.PointF]::new(($Cx - $triW/2), ($topCy + $triH/2)),
      [System.Drawing.PointF]::new(($Cx + $triW/2), ($topCy + $triH/2))
    )
    $Gfx.FillPolygon($fill, $up)
    $Gfx.DrawPolygon($stroke, $up)
    # Down triangle (bottom half)
    $botCy = $Cy + $gap/2 + $triH/2
    $down = @(
      [System.Drawing.PointF]::new($Cx, ($botCy + $triH/2)),
      [System.Drawing.PointF]::new(($Cx - $triW/2), ($botCy - $triH/2)),
      [System.Drawing.PointF]::new(($Cx + $triW/2), ($botCy - $triH/2))
    )
    $Gfx.FillPolygon($fill, $down)
    $Gfx.DrawPolygon($stroke, $down)
  }
  $fill.Dispose()
  $stroke.Dispose()
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
