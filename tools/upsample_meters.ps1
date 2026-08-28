# Upsample vertical meter sprite strip (needle 0%..100%) without overwriting source.
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$Dest,
  [int]$OrigFrames = 16,
  [int]$NewFrames = 64
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$im = [System.Drawing.Bitmap]::FromFile($Source)
$fw = $im.Width
$fh = [int]($im.Height / $OrigFrames)
if ($fh * $OrigFrames -ne $im.Height) {
  throw "Height $($im.Height) is not divisible by $OrigFrames frames"
}

$sumX = 0.0; $sumY = 0.0; $cnt = 0
for ($y = 0; $y -lt $fh; $y++) {
  for ($x = 0; $x -lt $fw; $x++) {
    $c = $im.GetPixel($x, $y)
    if ($c.R -gt 200 -and $c.G -gt 200 -and $c.B -gt 200) {
      $sumX += $x; $sumY += $y; $cnt++
    }
  }
}
$cx = 15.5; $cy = 15.5
if ($cnt -gt 0) {
  $tcx = $sumX / $cnt
  $tcy = $sumY / $cnt
  if ([Math]::Abs($tcx - 15.5) -lt 2 -and [Math]::Abs($tcy - 15.5) -lt 2) {
    $cx = 15.5; $cy = 15.5
  } else {
    $cx = $tcx; $cy = $tcy
  }
}
Write-Host ("Center={0:N2},{1:N2} frame={2}x{3}" -f $cx, $cy, $fw, $fh)

$nPix = $fw * $fh
$br = New-Object 'int[]' $nPix
$bg = New-Object 'int[]' $nPix
$bb = New-Object 'int[]' $nPix
$mid = [int]($OrigFrames / 2)
for ($y = 0; $y -lt $fh; $y++) {
  for ($x = 0; $x -lt $fw; $x++) {
    $rs = New-Object 'int[]' $OrigFrames
    $gs = New-Object 'int[]' $OrigFrames
    $bs = New-Object 'int[]' $OrigFrames
    for ($f = 0; $f -lt $OrigFrames; $f++) {
      $c = $im.GetPixel($x, ($f * $fh + $y))
      $rs[$f] = [int]$c.R
      $gs[$f] = [int]$c.G
      $bs[$f] = [int]$c.B
    }
    [Array]::Sort($rs)
    [Array]::Sort($gs)
    [Array]::Sort($bs)
    $i = ($y * $fw + $x)
    $br[$i] = $rs[$mid]
    $bg[$i] = $gs[$mid]
    $bb[$i] = $bs[$mid]
  }
}
Write-Host ("Base sample (0,0)=R{0}G{1}B{2} (15,8)=R{3}G{4}B{5}" -f $br[0], $bg[0], $bb[0], $br[(8 * $fw + 15)], $bg[(8 * $fw + 15)], $bb[(8 * $fw + 15)])

function Test-IsNeedle([int]$r, [int]$g, [int]$b, [int]$x, [int]$y) {
  $dxI = $x - 19
  $dyI = $y - 26
  if (($dxI * $dxI + $dyI * $dyI) -le 10) { return $false }
  if ($r -lt 150) { return $false }
  if (($r - $g) -lt 80) { return $false }
  if (($r - $b) -lt 80) { return $false }
  if ($g -gt 110 -or $b -gt 110) { return $false }
  return $true
}

$angles = New-Object 'double[]' $OrigFrames
for ($f = 0; $f -lt $OrigFrames; $f++) {
  $vx = 0.0; $vy = 0.0; $np = 0
  for ($y = 0; $y -lt $fh; $y++) {
    for ($x = 0; $x -lt $fw; $x++) {
      $c = $im.GetPixel($x, ($f * $fh + $y))
      if (-not (Test-IsNeedle ([int]$c.R) ([int]$c.G) ([int]$c.B) $x $y)) { continue }
      $dx = [double]($x - $cx)
      $dy = [double]($y - $cy)
      $dist = [Math]::Sqrt($dx * $dx + $dy * $dy)
      if ($dist -lt 2.5 -or $dist -gt 15) { continue }
      $w = $dist * $dist
      $vx += ($dx / $dist) * $w
      $vy += ($dy / $dist) * $w
      $np++
    }
  }
  $angles[$f] = [Math]::Atan2($vy, $vx) * 180.0 / [Math]::PI
  Write-Host ("orig[{0,2}] n={1,3} ang={2,8:N2}" -f $f, $np, $angles[$f])
}

$u = New-Object 'double[]' $OrigFrames
$u[0] = $angles[0]
for ($f = 1; $f -lt $OrigFrames; $f++) {
  $a = $angles[$f]
  while (($a - $u[$f - 1]) -lt -180) { $a += 360 }
  while (($a - $u[$f - 1]) -gt 180) { $a -= 360 }
  if ($a -lt $u[$f - 1]) { $a += 360 }
  $u[$f] = $a
}
$startAng = $u[0]
$endAng = $u[$OrigFrames - 1]
Write-Host ("Sweep {0:N2} -> {1:N2} delta={2:N2}" -f $startAng, $endAng, ($endAng - $startAng))

$tf = 7
$needleDx = New-Object 'System.Collections.Generic.List[double]'
$needleDy = New-Object 'System.Collections.Generic.List[double]'
$needleR = New-Object 'System.Collections.Generic.List[int]'
$needleG = New-Object 'System.Collections.Generic.List[int]'
$needleB = New-Object 'System.Collections.Generic.List[int]'
for ($y = 0; $y -lt $fh; $y++) {
  for ($x = 0; $x -lt $fw; $x++) {
    $c = $im.GetPixel($x, ($tf * $fh + $y))
    $i = ($y * $fw + $x)
    $diff = [Math]::Abs(([int]$c.R) - $br[$i]) + [Math]::Abs(([int]$c.G) - $bg[$i]) + [Math]::Abs(([int]$c.B) - $bb[$i])
    if ($diff -lt 35) { continue }
    if (([int]$c.R) -le (([int]$c.G) + 40)) { continue }
    if (([int]$c.R) -le (([int]$c.B) + 40)) { continue }
    if (([int]$c.R) -lt 100) { continue }
    $dxI = $x - 19
    $dyI = $y - 26
    if (($dxI * $dxI + $dyI * $dyI) -le 8) { continue }
    $needleDx.Add(($x - $cx)) | Out-Null
    $needleDy.Add(($y - $cy)) | Out-Null
    $needleR.Add([int]$c.R) | Out-Null
    $needleG.Add([int]$c.G) | Out-Null
    $needleB.Add([int]$c.B) | Out-Null
  }
}
Write-Host ("Needle template pts={0}" -f $needleDx.Count)
$needleAng = $u[$tf] * [Math]::PI / 180.0

$out = New-Object System.Drawing.Bitmap $fw, ($fh * $NewFrames), ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
for ($nf = 0; $nf -lt $NewFrames; $nf++) {
  $t = $nf / [double]($NewFrames - 1)
  $targetAng = ($startAng + ($endAng - $startAng) * $t) * [Math]::PI / 180.0
  $rot = $targetAng - $needleAng
  $cos = [Math]::Cos($rot)
  $sin = [Math]::Sin($rot)

  for ($y = 0; $y -lt $fh; $y++) {
    for ($x = 0; $x -lt $fw; $x++) {
      $i = ($y * $fw + $x)
      $col = [System.Drawing.Color]::FromArgb($br[$i], $bg[$i], $bb[$i])
      $out.SetPixel($x, ($nf * $fh + $y), $col)
    }
  }

  $cov = New-Object 'double[]' $nPix
  $accR = New-Object 'double[]' $nPix
  $accG = New-Object 'double[]' $nPix
  $accB = New-Object 'double[]' $nPix

  for ($pi = 0; $pi -lt $needleDx.Count; $pi++) {
    $ndx = $needleDx[$pi]
    $ndy = $needleDy[$pi]
    $rdx = $ndx * $cos - $ndy * $sin
    $rdy = $ndx * $sin + $ndy * $cos
    $fx = $cx + $rdx
    $fy = $cy + $rdy
    $x0 = [int][Math]::Floor($fx)
    $y0 = [int][Math]::Floor($fy)
    $fxf = $fx - $x0
    $fyf = $fy - $y0
    for ($oy = 0; $oy -le 1; $oy++) {
      for ($ox = 0; $ox -le 1; $ox++) {
        $px = $x0 + $ox
        $py = $y0 + $oy
        if ($px -lt 0 -or $px -ge $fw -or $py -lt 0 -or $py -ge $fh) { continue }
        if ($ox -eq 0) { $wx = 1.0 - $fxf } else { $wx = $fxf }
        if ($oy -eq 0) { $wy = 1.0 - $fyf } else { $wy = $fyf }
        $w = $wx * $wy
        if ($w -lt 0.02) { continue }
        $i = ($py * $fw + $px)
        $cov[$i] = $cov[$i] + $w
        $accR[$i] = $accR[$i] + $needleR[$pi] * $w
        $accG[$i] = $accG[$i] + $needleG[$pi] * $w
        $accB[$i] = $accB[$i] + $needleB[$pi] * $w
      }
    }
  }

  for ($y = 0; $y -lt $fh; $y++) {
    for ($x = 0; $x -lt $fw; $x++) {
      $i = ($y * $fw + $x)
      $a = $cov[$i]
      if ($a -lt 0.05) { continue }
      if ($a -gt 1.0) { $a = 1.0 }
      $nr = $accR[$i] / $cov[$i]
      $ng = $accG[$i] / $cov[$i]
      $nb = $accB[$i] / $cov[$i]
      $cur = $out.GetPixel($x, ($nf * $fh + $y))
      $rr = [int][Math]::Round($cur.R * (1.0 - $a) + $nr * $a)
      $gg = [int][Math]::Round($cur.G * (1.0 - $a) + $ng * $a)
      $bb2 = [int][Math]::Round($cur.B * (1.0 - $a) + $nb * $a)
      if ($rr -lt 0) { $rr = 0 }
      if ($rr -gt 255) { $rr = 255 }
      if ($gg -lt 0) { $gg = 0 }
      if ($gg -gt 255) { $gg = 255 }
      if ($bb2 -lt 0) { $bb2 = 0 }
      if ($bb2 -gt 255) { $bb2 = 255 }
      $out.SetPixel($x, ($nf * $fh + $y), [System.Drawing.Color]::FromArgb($rr, $gg, $bb2))
    }
  }
}

$destDir = Split-Path -Parent $Dest
if ($destDir -and -not (Test-Path $destDir)) {
  New-Item -ItemType Directory -Path $destDir | Out-Null
}
if (Test-Path $Dest) { Remove-Item -LiteralPath $Dest -Force }
$out.Save($Dest, [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host ("Saved {0} ({1}x{2})" -f $Dest, $out.Width, $out.Height)
# verify before dispose
$v0 = $out.GetPixel(0, 0)
$v1 = $out.GetPixel(15, 8)
Write-Host ("Verify out (0,0)=R{0}G{1}B{2} (15,8)=R{3}G{4}B{5}" -f $v0.R, $v0.G, $v0.B, $v1.R, $v1.G, $v1.B)
$out.Dispose()
$im.Dispose()
