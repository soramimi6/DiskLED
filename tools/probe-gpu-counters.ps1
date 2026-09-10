# probe-gpu-counters.ps1  --  pre-verification probe for PLANNED-3.2.0 item 4 (GPU utilization).
#
# Read-only. Polls "\GPU Engine(*)\Utilization Percentage" and reports what a
# Delphi PDH-wildcard implementation would have to deal with:
#   - instance count and how it churns between polls (dynamic instances)
#   - wall-clock cost of one Get-Counter enumeration
#   - per-adapter (LUID) utilization = max over engine types of (sum over PIDs)
#   - "busiest GPU" = max over adapters   (the value the donut would show)
#
# Compare the per-adapter numbers against Task Manager's Performance tab
# (each GPU card's headline "Utilization" = max over that GPU's engines).
#
# Usage:   pwsh tools/probe-gpu-counters.ps1 [-IntervalSec 2] [-Count 30]

param(
    [double]$IntervalSec = 2,
    [int]$Count = 30
)

$ErrorActionPreference = 'Stop'

# LUID -> friendly name is not exposed by WMI; list adapters so the operator
# can correlate "which GPU is luid X" by watching which one goes busy.
Write-Host "Video controllers on this machine:" -ForegroundColor Cyan
Get-CimInstance Win32_VideoController |
    Select-Object Name, @{n = 'DriverVer'; e = { $_.DriverVersion } } |
    Format-Table -AutoSize | Out-String | Write-Host

if (-not (Get-Counter -ListSet 'GPU Engine' -ErrorAction SilentlyContinue)) {
    Write-Warning "No 'GPU Engine' counter set on this machine. A Delphi impl must treat this as 'GPU section unavailable' (donut/graph = 0), not an error."
    return
}

$rx = '_luid_(?<luid>0x[0-9A-Fa-f]+_0x[0-9A-Fa-f]+)_phys_(?<phys>\d+)_eng_(?<eng>\d+)_engtype_(?<engtype>\w+)'
$prevInstances = $null

for ($i = 1; $i -le $Count; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $sample = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
    }
    catch {
        Write-Host ("[{0,3}] Get-Counter failed: {1}" -f $i, $_.Exception.Message) -ForegroundColor Yellow
        Start-Sleep -Seconds $IntervalSec
        continue
    }
    $sw.Stop()

    $samples = $sample.CounterSamples
    $instCount = $samples.Count

    # group by (luid, engtype), summing across PIDs and physical engines
    $byAdapterEngine = @{}
    foreach ($s in $samples) {
        if ($s.InstanceName -notmatch $rx) { continue }
        $luid = $Matches['luid']
        $engtype = $Matches['engtype']
        $key = "$luid|$engtype"
        $byAdapterEngine[$key] = [double]($byAdapterEngine[$key]) + [double]$s.CookedValue
    }

    # per adapter: max over engine types
    $perAdapter = @{}
    foreach ($kv in $byAdapterEngine.GetEnumerator()) {
        $luid = $kv.Key.Split('|')[0]
        $v = [math]::Min(100, $kv.Value)
        if ($v -gt [double]($perAdapter[$luid])) { $perAdapter[$luid] = $v }
    }

    $busiest = 0.0
    foreach ($v in $perAdapter.Values) { if ($v -gt $busiest) { $busiest = $v } }

    # instance churn vs previous poll
    $curKeys = $samples.InstanceName
    $churn = ''
    if ($prevInstances) {
        $added = (Compare-Object $prevInstances $curKeys | Where-Object SideIndicator -eq '=>').Count
        $removed = (Compare-Object $prevInstances $curKeys | Where-Object SideIndicator -eq '<=').Count
        $churn = "  churn +$added/-$removed"
    }
    $prevInstances = $curKeys

    $adapterStr = ($perAdapter.GetEnumerator() | Sort-Object Name |
        ForEach-Object { "{0}={1,5:N1}%" -f $_.Key, $_.Value }) -join '  '

    Write-Host ("[{0,3}] inst={1,3}  enum={2,4}ms{3}  |  busiest={4,5:N1}%   {5}" -f `
            $i, $instCount, $sw.ElapsedMilliseconds, $churn, $busiest, $adapterStr)

    Start-Sleep -Seconds $IntervalSec
}

Write-Host "`nNotes for the Delphi impl:" -ForegroundColor Cyan
Write-Host "  - 'inst' is how many counter instances exist (one per PID x engine). It's typically hundreds and"
Write-Host "    churns as apps open/close GPU contexts -> build the query once, re-expand the wildcard only"
Write-Host "    occasionally (every N seconds or on churn), and read with PdhGetFormattedCounterArray each sample."
Write-Host "  - 'enum' here is dominated by the Get-Counter cmdlet's own path-expansion + name resolution per call"
Write-Host "    (~seconds). A native PDH persistent query does NOT pay that; only the one-off wildcard re-expansion is"
Write-Host "    costly. Measure the real cost in the Delphi spike, not from this number."
Write-Host "  - aggregation used here: sum over PIDs per (luid,engtype) -> max over engtype per adapter -> max over adapters."
Write-Host "  - decide whether to drop virtual display adapters (e.g. 'Meta Virtual Monitor') the way NICs filter virtual adapters."
