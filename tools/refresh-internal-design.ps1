# Regenerates the fact-derived part of docs/internal/ from the current tree.
#
# HYBRID MODEL (see docs/internal/REGEN.md):
#   - This script owns docs/internal/GENERATED-reference.md ONLY. It rewrites that
#     file wholesale every run, from the Delphi source, .dproj and layout.cfg files.
#   - The hand-written 00..18 chapters are NOT touched here. After a master release,
#     a human/agent diffs master and updates the prose chapters, using this file's
#     output as the source of truth for unit lists, public APIs, ini keys, strings,
#     display modes and tunable constants.
#
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File tools\refresh-internal-design.ps1
#
# ASCII-only on purpose: Windows PowerShell 5.1 parses .ps1 as ANSI unless the file
# has a UTF-8 BOM. All Japanese in the output comes from source files, which are
# read back with -Encoding UTF8.

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Root 'src'
$Out = Join-Path $Root 'docs\internal\GENERATED-reference.md'

if (-not (Test-Path -LiteralPath $Src)) { Write-Error "src/ not found under $Root" }

function Read-Utf8([string]$path) { Get-Content -LiteralPath $path -Raw -Encoding UTF8 }

function Get-DprojValue([string]$pattern) {
    $dproj = Join-Path $Root 'DiskLED.dproj'
    if (-not (Test-Path -LiteralPath $dproj)) { return '' }
    $m = [regex]::Match((Read-Utf8 $dproj), $pattern)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return ''
}

function Get-UnitInfo([string]$path) {
    $rel = $path.Substring($Root.Length + 1) -replace '\\', '/'
    $raw = Read-Utf8 $path
    $loc = ($raw -split "`n").Count

    $ifStart = $raw.IndexOf("`ninterface")
    $implStart = $raw.IndexOf("`nimplementation")
    if ($ifStart -lt 0) { $ifStart = 0 }
    if ($implStart -lt 0) { $implStart = $raw.Length }
    $iface = $raw.Substring($ifStart, $implStart - $ifStart)

    $doc = ''
    $head = $raw.Substring(0, [Math]::Max(1, $ifStart))
    $mDoc = [regex]::Match($head, '\{(.+?)\}', 'Singleline')
    if ($mDoc.Success) {
        $doc = ($mDoc.Groups[1].Value -replace '\s+', ' ').Trim()
        if ($doc.Length -gt 260) { $doc = $doc.Substring(0, 257) + '...' }
    }

    $types = @()
    foreach ($m in [regex]::Matches($iface, '(?m)^\s{2,4}(T[A-Za-z0-9_]+)\s*=\s*(class|record|interface|\(|set of|array)')) {
        $types += $m.Groups[1].Value
    }
    $routines = @()
    foreach ($m in [regex]::Matches($iface, '(?m)^(function|procedure)\s+([A-Za-z0-9_]+)')) {
        $routines += $m.Groups[2].Value
    }

    [pscustomobject]@{
        Rel      = $rel
        Loc      = $loc
        Doc      = $doc
        Types    = @($types | Select-Object -Unique)
        Routines = @($routines | Select-Object -Unique)
    }
}

function Get-IniKeys {
    $raw = Read-Utf8 (Join-Path $Src 'uSettings.pas')
    $rows = @()
    foreach ($m in [regex]::Matches($raw, "Ini\.(?:Read|Write)(String|Bool|Integer|Float)\('([^']+)',\s*'([^']+)'")) {
        $rows += [pscustomobject]@{ Section = $m.Groups[2].Value; Key = $m.Groups[3].Value; Type = $m.Groups[1].Value }
    }
    $rows | Sort-Object Section, Key -Unique
}

function Get-AppStrings {
    $raw = Read-Utf8 (Join-Path $Src 'uAppStrings.pas')
    $rows = @()
    foreach ($m in [regex]::Matches($raw, "AddStr\('([^']+)',\s*'((?:[^']|'')*)',\s*'((?:[^']|'')*)'\s*\)")) {
        $rows += [pscustomobject]@{
            Id = $m.Groups[1].Value
            Ja = ($m.Groups[2].Value -replace "''", "'")
            En = ($m.Groups[3].Value -replace "''", "'")
        }
    }
    $rows
}

function Get-DisplayModes {
    $modes = @()
    Get-ChildItem -LiteralPath (Join-Path $Root 'assets') -Directory | ForEach-Object {
        $cfg = Join-Path $_.FullName 'layout.cfg'
        if (-not (Test-Path -LiteralPath $cfg)) { return }
        $t = Read-Utf8 $cfg
        $get = {
            param($k)
            $mm = [regex]::Match($t, "(?m)^$k=(.*)$")
            if ($mm.Success) { $mm.Groups[1].Value.Trim() } else { '' }
        }
        $modes += [pscustomobject]@{
            Dir     = $_.Name
            Id      = (& $get 'Id')
            Caption = (& $get 'Caption')
            Order   = (& $get 'Order')
            Default = (& $get 'Default')
            Size    = ('{0}x{1}' -f (& $get 'Width'), (& $get 'Height'))
            Full    = $(if ([regex]::IsMatch($t, '(?m)^\[ModeFull\]')) { 'yes' } else { 'no' })
        }
    }
    $modes | Sort-Object { [int]$_.Order }
}

function Get-FormDpi {
    # Every .dfm's Scaled flag + whether its .pas handles WM_DPICHANGED /
    # OnAfterMonitorDpiChanged. A Scaled=False form with neither is a DPI bug
    # (3.1.1 shipped the Trace Route window that way).
    $rows = @()
    Get-ChildItem -LiteralPath $Src -Recurse -Filter *.dfm |
        Where-Object { $_.FullName -notmatch '__history|__recovery' } |
        ForEach-Object {
            $dfm = Read-Utf8 $_.FullName
            $pasPath = [IO.Path]::ChangeExtension($_.FullName, '.pas')
            $pas = if (Test-Path -LiteralPath $pasPath) { Read-Utf8 $pasPath } else { '' }
            $scaled = if ($dfm -match '(?m)^\s*Scaled\s*=\s*False') { 'False' } else { 'True (default)' }
            $dpi =
                ($pas -match 'WM_DPICHANGED') -or
                ($dfm -match 'OnAfterMonitorDpiChanged') -or
                ($pas -match 'ChangeScale')
            $rows += [pscustomobject]@{
                Form   = $_.BaseName
                Scaled = $scaled
                DpiHandled = $(if ($dpi) { 'yes' } else { 'no' })
            }
        }
    $rows | Sort-Object Form
}

function Get-Constants {
    $files = @(
        'metrics\uDisplayPipeline.pas', 'metrics\uRangeEngine.pas', 'metrics\uMetricsTypes.pas',
        'metrics\uPingCollector.pas', 'metrics\uNetCollector.pas', 'metrics\uAudioCollector.pas',
        'metrics\uDiskCollector.pas', 'uDpiScale.pas', 'uWindowPlacement.pas'
    )
    $rows = @()
    foreach ($f in $files) {
        $p = Join-Path $Src $f
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $raw = Read-Utf8 $p
        # isolate `const ... <until next section keyword>` blocks so record fields
        # and local vars that happen to start with C are not picked up.
        foreach ($blk in [regex]::Matches($raw, '(?ms)^const\r?\n(.*?)^(?:type|var|implementation|function |procedure |constructor |destructor )')) {
            $body = $blk.Groups[1].Value
            foreach ($m in [regex]::Matches($body, "(?m)^\s{2,4}(C[A-Z][A-Za-z0-9_]*)\s*(?::[^=]+)?=\s*([^;]+);(?:\s*\{\s*(.*?)\s*\})?")) {
                $rows += [pscustomobject]@{
                    Unit    = ($f -replace '\\', '/')
                    Name    = $m.Groups[1].Value
                    Value   = ($m.Groups[2].Value -replace '\s+', ' ').Trim()
                    Comment = ($m.Groups[3].Value -replace '\s+', ' ').Trim()
                }
            }
        }
    }
    $rows
}

$units = Get-ChildItem -LiteralPath $Src -Recurse -Filter *.pas |
    Where-Object { $_.FullName -notmatch '__history|__recovery' } |
    Sort-Object FullName |
    ForEach-Object { Get-UnitInfo $_.FullName }

$head = & git -C $Root rev-parse --short HEAD 2>$null
$branch = & git -C $Root rev-parse --abbrev-ref HEAD 2>$null

$sb = [System.Text.StringBuilder]::new()
function W([string]$s) { [void]$sb.AppendLine($s) }

W '<!-- GENERATED by tools/refresh-internal-design.ps1 - do not edit by hand. -->'
W '<!-- Regenerate after every master release. See REGEN.md. -->'
W ''
W '# GENERATED reference (machine-extracted)'
W ''
W ('generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
W ('commit: {0}   branch: {1}' -f $head, $branch)
W ''
W 'Auto-extracted from `src/`, `DiskLED.dproj` and `assets/*/layout.cfg`. The hand-written'
W 'chapters 00-18 are updated by a human/agent using this table as the source of truth.'
W ''
W '## Build metadata'
W ''
W '| item | value |'
W '|---|---|'
W ('| FileVersion | {0} |' -f (Get-DprojValue 'FileVersion=([0-9.]+)'))
W ('| AppDPIAwarenessMode | {0} |' -f (Get-DprojValue '<AppDPIAwarenessMode>([^<]+)<'))
W ('| DCC_UnitSearchPath | {0} |' -f (Get-DprojValue '<DCC_UnitSearchPath>([^<]+)<'))
W ('| Icon_MainIcon | {0} |' -f (Get-DprojValue '<Icon_MainIcon>([^<]+)<'))
W ('| units (src/**/*.pas) | {0} |' -f $units.Count)
W ('| total lines | {0} |' -f (($units | Measure-Object Loc -Sum).Sum))
W ''
W '## Unit inventory'
W ''
W '| unit | LOC | public types | public routines |'
W '|---|---:|---|---|'
foreach ($u in $units) {
    $ty = ($u.Types -join ', '); $rt = ($u.Routines -join ', ')
    if ($ty.Length -gt 100) { $ty = $ty.Substring(0, 97) + '...' }
    if ($rt.Length -gt 100) { $rt = $rt.Substring(0, 97) + '...' }
    W ('| `{0}` | {1} | {2} | {3} |' -f $u.Rel, $u.Loc, $ty, $rt)
}
W ''
W '### Unit roles (leading doc comment)'
W ''
foreach ($u in ($units | Where-Object { $_.Doc })) { W ('- `{0}` - {1}' -f $u.Rel, $u.Doc) }
W ''
W '## DiskLED.ini keys'
W ''
W 'From Read*/Write* calls in `src/uSettings.pas`. Defaults: see `ApplyDefaults` / `Normalize`.'
W ''
W '| section | key | type |'
W '|---|---|---|'
foreach ($k in (Get-IniKeys)) { W ('| {0} | {1} | {2} |' -f $k.Section, $k.Key, $k.Type) }
W ''
W '## Display modes (assets/*/layout.cfg)'
W ''
W '| dir | Id | Caption | Order | Default | compact WxH | ModeFull |'
W '|---|---|---|---:|---|---|---|'
foreach ($m in (Get-DisplayModes)) {
    W ('| {0} | {1} | {2} | {3} | {4} | {5} | {6} |' -f $m.Dir, $m.Id, $m.Caption, $m.Order, $m.Default, $m.Size, $m.Full)
}
W ''
W '## Forms: Scaled flag / DPI handling'
W ''
W 'Scaled=False with DpiHandled=no is a high-DPI bug (see docs/internal/17 Section 17.6).'
W ''
W '| form | Scaled | DpiHandled |'
W '|---|---|---|'
foreach ($f in (Get-FormDpi)) {
    W ('| `{0}` | {1} | {2} |' -f $f.Form, $f.Scaled, $f.DpiHandled)
}
W ''
W '## UI string IDs (uAppStrings.pas)'
W ''
W '| id | ja | en |'
W '|---|---|---|'
foreach ($s in (Get-AppStrings)) {
    W ('| `{0}` | {1} | {2} |' -f $s.Id, ($s.Ja -replace '\|', '\|'), ($s.En -replace '\|', '\|'))
}
W ''
W '## Tunable constants'
W ''
W '| unit | const | value | note |'
W '|---|---|---|---|'
foreach ($c in (Get-Constants)) {
    W ('| `{0}` | `{1}` | `{2}` | {3} |' -f $c.Unit, $c.Name, $c.Value, ($c.Comment -replace '\|', '\|'))
}
W ''

$sb.ToString() | Out-File -LiteralPath $Out -Encoding utf8
Write-Host "Wrote $Out"
Write-Host ('  units={0}  strings={1}  ini keys={2}  modes={3}' -f `
    $units.Count, (Get-AppStrings).Count, (Get-IniKeys).Count, (Get-DisplayModes).Count)
