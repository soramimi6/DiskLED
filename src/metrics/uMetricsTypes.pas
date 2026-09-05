unit uMetricsTypes;

interface

type
  TPingLevel = (plTimeout, plSlow, plFair, plNormal);
  TSpeedScale = (ssLinear, ssLog); { network meters/graphs only; disk stays linear }

  TMetricsSnapshot = record
    CpuUsage: Double;
    CpuUserPct: Double;
    CpuKernelPct: Double;
    CpuName: string;
    CpuCores: Integer;
    CpuThreads: Integer;
    CpuCurrentMhz: Integer;
    CpuMaxMhz: Integer;
    MemUsage: Double;
    SwapUsage: Double;
    DiskReadBps: Double;
    DiskWriteBps: Double;
    NetInBps: Double;
    NetOutBps: Double;
    NetLinkSpeedBps: Double; { Byte/s; 0 if unknown }
    MemUsedBytes: UInt64;
    MemTotalBytes: UInt64;
    MemAvailBytes: UInt64;
    MemCacheBytes: UInt64;
    MemCommitBytes: UInt64;
    MemCommitLimitBytes: UInt64;
    SwapUsedBytes: UInt64;
    SwapTotalBytes: UInt64;
    DiskQueue: Double;
    DiskReadIops: Double;
    DiskWriteIops: Double;
    DiskActivePct: Double; { 0..100; -1 unknown }
    DiskLatencyMs: Double; { Avg. Disk sec/Transfer, converted to ms }
    PowerAc: Boolean;
    PowerBatteryPresent: Boolean;
    PowerBatteryPercent: Integer; { 0..100; -1 unknown }
    PowerRemainSec: Integer; { battery remaining seconds; -1 unknown }
    PingRttMs: Double;
    PingOk: Boolean;
    PingPending: Boolean;
    PingLevel: TPingLevel;
    PingEnabled: Boolean;
    PingTarget: string; { host actually used for last/next probe }
    AudioPeak: Double; { 0..1 mono equivalent: max of all metering channels }
    AudioPeakL: Double; { 0..1 front left (channel 0) }
    AudioPeakR: Double; { 0..1 front right (channel 1); 0 if mono device }
    AudioDeviceName: string; { default render endpoint friendly name }
    TickMs: Cardinal;
  end;

  TBallisticKind = (bkVu, bkBar, bkPeak);

  TBallisticParams = record
    Kind: TBallisticKind;
    Strength: Integer; { 0..100; rise tightness. Fall speed is Kind-only. }
  end;

  TMeterBallistics = record
    Cpu: TBallisticParams;
    Mem: TBallisticParams;
    Swap: TBallisticParams;
    DiskRead: TBallisticParams;
    DiskWrite: TBallisticParams;
    NetIn: TBallisticParams;
    NetOut: TBallisticParams;
    Audio: TBallisticParams;
    AudioL: TBallisticParams;
    AudioR: TBallisticParams;
  end;

  { Range-normalized 0..1, before ballistic follow. Graph history uses this. }
  TNormalizedMetrics = record
    Cpu: Double;
    Mem: Double;
    Swap: Double;
    DiskRead: Double;
    DiskWrite: Double;
    NetIn: Double;
    NetOut: Double;
    Audio: Double;
    AudioL: Double;
    AudioR: Double;
  end;

  TDisplayState = record
    Cpu: Double;
    Mem: Double;
    Swap: Double;
    { Digit readout (held; slower than meter bars). }
    CpuDigit: Double;
    MemDigit: Double;
    SwapDigit: Double;
    DiskRead: Double;
    DiskWrite: Double;
    NetIn: Double;
    NetOut: Double;
    Audio: Double;
    AudioL: Double;
    AudioR: Double;
    DiskReadOn: Boolean;
    DiskWriteOn: Boolean;
    DiskRWOn: Boolean;
    NetInOn: Boolean;
    NetOutOn: Boolean;
    NetActivityOn: Boolean;
    PingLevel: TPingLevel;
    PingPending: Boolean;
  end;

  TNetAdapterInfo = record
    Index: Cardinal;
    FriendlyName: string;
    Descr: string;
    LinkSpeedBps: Double;
    Included: Boolean;
    IsLoopback: Boolean;
    Ipv4: string;
    Gateway: string;
    DhcpEnabled: Boolean;
  end;

  TPingHistoryEntry = record
    When: TDateTime;
    Target: string;
    RttMs: Double;
    Ok: Boolean;
    Level: TPingLevel;
  end;

const
  CNoiseFloorBps = 4096.0; { ignore below 4 KiB/s }

function Clamp01(const AValue: Double): Double;
function ClampStrength(AValue: Integer): Integer;
function IsActiveBps(const ABps: Double): Boolean;
function FormatRateBps(ABps: Double): string;
function FormatLinkSpeedBps(ABps: Double): string;
function FormatBytesPair(AUsed, ATotal: UInt64): string;
function FormatBytesGiB(ABytes: UInt64): string;
function FormatIops(AIops: Double): string;
function FormatLatencyMs(AMs: Double): string;
function DefaultBallisticParams: TBallisticParams;
function DefaultMeterBallistics: TMeterBallistics;

implementation

uses
  System.SysUtils;

function Clamp01(const AValue: Double): Double;
begin
  if AValue < 0 then
    Result := 0
  else if AValue > 1 then
    Result := 1
  else
    Result := AValue;
end;

function IsActiveBps(const ABps: Double): Boolean;
begin
  Result := ABps > CNoiseFloorBps;
end;

function FormatRateBps(ABps: Double): string;
const
  CKiB = 1024.0;
  CMiB = 1024.0 * 1024.0;
  CGiB = 1024.0 * 1024.0 * 1024.0;
var
  V: Double;
  UnitLabel: string;
begin
  if ABps < 0 then
    ABps := 0;
  if ABps < CKiB then
    Exit(Format('%d B/s', [Round(ABps)]));
  if ABps < CMiB then
  begin
    V := ABps / CKiB;
    UnitLabel := 'KB/s';
  end
  else if ABps < CGiB then
  begin
    V := ABps / CMiB;
    UnitLabel := 'MB/s';
  end
  else
  begin
    V := ABps / CGiB;
    UnitLabel := 'GB/s';
  end;
  if V >= 100 then
    Result := Format('%.0f %s', [V, UnitLabel])
  else if V >= 10 then
    Result := Format('%.1f %s', [V, UnitLabel])
  else
    Result := Format('%.2f %s', [V, UnitLabel]);
end;

function FormatBytesPair(AUsed, ATotal: UInt64): string;
const
  CGiB = 1024.0 * 1024.0 * 1024.0;
var
  U, T: Double;
begin
  if ATotal = 0 then
    Exit(#$2014);
  U := AUsed / CGiB;
  T := ATotal / CGiB;
  if T >= 10 then
    Result := Format('%.1f / %.1f GB', [U, T])
  else
    Result := Format('%.2f / %.2f GB', [U, T]);
end;

function FormatBytesGiB(ABytes: UInt64): string;
const
  CGiB = 1024.0 * 1024.0 * 1024.0;
var
  V: Double;
begin
  V := ABytes / CGiB;
  if V >= 10 then
    Result := Format('%.1f GB', [V])
  else
    Result := Format('%.2f GB', [V]);
end;

function FormatIops(AIops: Double): string;
begin
  if AIops < 0 then
    AIops := 0;
  if AIops >= 100 then
    Result := Format('%.0f', [AIops])
  else if AIops >= 10 then
    Result := Format('%.1f', [AIops])
  else
    Result := Format('%.2f', [AIops]);
end;

function FormatLatencyMs(AMs: Double): string;
begin
  if AMs < 0 then
    AMs := 0;
  if AMs >= 100 then
    Result := Format('%.0f ms', [AMs])
  else if AMs >= 10 then
    Result := Format('%.1f ms', [AMs])
  else
    Result := Format('%.2f ms', [AMs]);
end;

function FormatLinkSpeedBps(ABps: Double): string;
var
  Mbps: Double;
begin
  if ABps <= 0 then
    Exit(#$2014);
  Mbps := (ABps * 8) / (1000 * 1000);
  if Mbps >= 1000 then
    Result := Format('%.1f Gbps', [Mbps / 1000])
  else if Mbps >= 100 then
    Result := Format('%.0f Mbps', [Mbps])
  else
    Result := Format('%.0f Mbps', [Mbps]);
end;

function ClampStrength(AValue: Integer): Integer;
begin
  if AValue < 0 then
    Result := 0
  else if AValue > 100 then
    Result := 100
  else
    Result := AValue;
end;

function DefaultBallisticParams: TBallisticParams;
begin
  Result.Kind := bkVu;
  Result.Strength := 50;
end;

function DefaultMeterBallistics: TMeterBallistics;
var
  P: TBallisticParams;
begin
  P := DefaultBallisticParams;
  Result.Cpu := P;
  Result.Mem := P;
  Result.Swap := P;
  Result.DiskRead := P;
  Result.DiskWrite := P;
  Result.NetIn := P;
  Result.NetOut := P;
  Result.Audio := P;
  Result.Audio.Kind := bkPeak;
  Result.AudioL := Result.Audio;
  Result.AudioR := Result.Audio;
end;

end.
