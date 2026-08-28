unit uMetricsTypes;

interface

type
  TPingLevel = (plTimeout, plSlow, plFair, plNormal);

  TMetricsSnapshot = record
    CpuUsage: Double;
    MemUsage: Double;
    SwapUsage: Double;
    DiskReadBps: Double;
    DiskWriteBps: Double;
    NetInBps: Double;
    NetOutBps: Double;
    NetLinkSpeedBps: Double; { Byte/s; 0 if unknown }
    PingRttMs: Double;
    PingOk: Boolean;
    PingPending: Boolean;
    PingLevel: TPingLevel;
    PingEnabled: Boolean;
    PingTarget: string; { host actually used for last/next probe }
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
    DiskReadOn: Boolean;
    DiskWriteOn: Boolean;
    DiskRWOn: Boolean;
    NetInOn: Boolean;
    NetOutOn: Boolean;
    NetActivityOn: Boolean;
    PingLevel: TPingLevel;
    PingPending: Boolean;
  end;

const
  CNoiseFloorBps = 4096.0; { ignore below 4 KiB/s }

function Clamp01(const AValue: Double): Double;
function ClampStrength(AValue: Integer): Integer;
function IsActiveBps(const ABps: Double): Boolean;
function FormatRateBps(ABps: Double): string;
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
end;

end.
