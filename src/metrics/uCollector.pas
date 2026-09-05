unit uCollector;

interface

uses
  uMetricsTypes,
  uCpuCollector,
  uMemCollector,
  uDiskCollector,
  uNetCollector,
  uPingCollector,
  uAudioCollector;

type
  TMetricsCollector = class
  private
    FCpu: TCpuCollector;
    FMem: TMemCollector;
    FDisk: TDiskCollector;
    FNet: TNetCollector;
    FPing: TPingCollector;
    FAudio: TAudioCollector;
  public
    constructor Create;
    destructor Destroy; override;
    function Collect: TMetricsSnapshot;
    procedure RequestPing;
    procedure TickPing;
    procedure ApplyPingSettings(AEnabled: Boolean; AIntervalSec: Integer;
      const AHost: string; AAutoGateway: Boolean;
      AFairMs, ASlowMs, ATimeoutMs: Integer);
    procedure CopyNetAdapters(out AList: TArray<TNetAdapterInfo>);
    procedure CopyPingHistory(out AEntries: TArray<TPingHistoryEntry>);
  end;

implementation

uses
  Winapi.Windows;

constructor TMetricsCollector.Create;
begin
  inherited Create;
  FCpu := TCpuCollector.Create;
  FMem := TMemCollector.Create;
  FDisk := TDiskCollector.Create;
  FNet := TNetCollector.Create;
  FPing := TPingCollector.Create;
  FAudio := TAudioCollector.Create;
end;

destructor TMetricsCollector.Destroy;
begin
  FAudio.Free;
  FPing.Free;
  FNet.Free;
  FDisk.Free;
  FMem.Free;
  FCpu.Free;
  inherited;
end;

function TMetricsCollector.Collect: TMetricsSnapshot;
var
  Power: TSystemPowerStatus;
begin
  Result := Default(TMetricsSnapshot);
  Result.DiskActivePct := -1;
  Result.DiskLatencyMs := -1;
  try
    Result.CpuUsage := FCpu.Sample;
    Result.CpuUserPct := FCpu.UserPct;
    Result.CpuKernelPct := FCpu.KernelPct;
    Result.CpuName := FCpu.Name;
    Result.CpuCores := FCpu.Cores;
    Result.CpuThreads := FCpu.Threads;
    Result.CpuCurrentMhz := FCpu.CurrentMhz;
    Result.CpuMaxMhz := FCpu.MaxMhz;
  except
    Result.CpuUsage := 0;
    Result.CpuUserPct := 0;
    Result.CpuKernelPct := 0;
  end;
  try
    FMem.Sample(Result.MemUsage, Result.SwapUsage,
      Result.MemUsedBytes, Result.MemTotalBytes,
      Result.MemAvailBytes, Result.MemCacheBytes,
      Result.SwapUsedBytes, Result.SwapTotalBytes,
      Result.MemCommitBytes, Result.MemCommitLimitBytes);
  except
    Result.MemUsage := 0;
    Result.SwapUsage := 0;
    Result.MemUsedBytes := 0;
    Result.MemTotalBytes := 0;
    Result.MemAvailBytes := 0;
    Result.MemCacheBytes := 0;
    Result.SwapUsedBytes := 0;
    Result.SwapTotalBytes := 0;
    Result.MemCommitBytes := 0;
    Result.MemCommitLimitBytes := 0;
  end;
  try
    FDisk.Sample(Result.DiskReadBps, Result.DiskWriteBps,
      Result.DiskQueue, Result.DiskReadIops, Result.DiskWriteIops,
      Result.DiskActivePct, Result.DiskLatencyMs);
  except
    Result.DiskReadBps := 0;
    Result.DiskWriteBps := 0;
    Result.DiskQueue := 0;
    Result.DiskReadIops := 0;
    Result.DiskWriteIops := 0;
    Result.DiskActivePct := -1;
    Result.DiskLatencyMs := -1;
  end;
  try
    FNet.Sample(Result.NetInBps, Result.NetOutBps, Result.NetLinkSpeedBps);
  except
    Result.NetInBps := 0;
    Result.NetOutBps := 0;
    Result.NetLinkSpeedBps := 0;
  end;
  FPing.CopyTo(Result);
  try
    FAudio.Sample(Result.AudioPeakL, Result.AudioPeakR, Result.AudioPeak,
      Result.AudioDeviceName);
  except
    Result.AudioPeak := 0;
    Result.AudioPeakL := 0;
    Result.AudioPeakR := 0;
    Result.AudioDeviceName := '';
  end;
  try
    FillChar(Power, SizeOf(Power), 0);
    if GetSystemPowerStatus(Power) then
    begin
      Result.PowerAc := Power.ACLineStatus <> 0;
      Result.PowerBatteryPresent := (Power.BatteryFlag and $80) = 0;
      if Power.BatteryLifePercent <= 100 then
        Result.PowerBatteryPercent := Power.BatteryLifePercent
      else
        Result.PowerBatteryPercent := -1;
      if Power.BatteryLifeTime <> DWORD(-1) then
        Result.PowerRemainSec := Integer(Power.BatteryLifeTime)
      else
        Result.PowerRemainSec := -1;
    end
    else
    begin
      Result.PowerAc := True;
      Result.PowerBatteryPresent := False;
      Result.PowerBatteryPercent := -1;
      Result.PowerRemainSec := -1;
    end;
  except
    Result.PowerAc := True;
    Result.PowerBatteryPresent := False;
    Result.PowerBatteryPercent := -1;
    Result.PowerRemainSec := -1;
  end;
  Result.TickMs := GetTickCount;
end;

procedure TMetricsCollector.RequestPing;
begin
  FPing.RequestNow;
end;

procedure TMetricsCollector.TickPing;
begin
  FPing.Tick;
end;

procedure TMetricsCollector.ApplyPingSettings(AEnabled: Boolean; AIntervalSec: Integer;
  const AHost: string; AAutoGateway: Boolean;
  AFairMs, ASlowMs, ATimeoutMs: Integer);
begin
  FPing.ApplyConfig(AEnabled, AIntervalSec, AHost, AAutoGateway,
    AFairMs, ASlowMs, ATimeoutMs);
end;

procedure TMetricsCollector.CopyNetAdapters(out AList: TArray<TNetAdapterInfo>);
begin
  FNet.CopyDisplayAdapters(AList);
end;

procedure TMetricsCollector.CopyPingHistory(out AEntries: TArray<TPingHistoryEntry>);
begin
  FPing.CopyPingHistory(AEntries);
end;

end.
