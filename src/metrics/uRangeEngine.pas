unit uRangeEngine;

{ Speed ceilings for Disk/Net meters. Net prefers link speed (linear or log).
  Disk uses decaying peak auto-sense and is always linear. }

interface

uses
  uMetricsTypes;

type
  TRangeEngine = class
  private
    FDiskMaxBps: Double;
    FNetMaxBps: Double;
    FSpeedScale: TSpeedScale;
    function LinearNorm(ABps, ARangeMax: Double): Double;
    function NetNorm(ABps, ARangeMax: Double): Double;
  public
    constructor Create;
    procedure Observe(const ASnap: TMetricsSnapshot);
    function DiskReadNorm(const ASnap: TMetricsSnapshot): Double;
    function DiskWriteNorm(const ASnap: TMetricsSnapshot): Double;
    function NetInNorm(const ASnap: TMetricsSnapshot): Double;
    function NetOutNorm(const ASnap: TMetricsSnapshot): Double;
    property SpeedScale: TSpeedScale read FSpeedScale write FSpeedScale;
  end;

implementation

uses
  System.Math;

const
  CDiskMinBps = 10.0 * 1024.0 * 1024.0;       { 10 MB/s floor }
  CDiskMaxCapBps = 1024.0 * 1024.0 * 1024.0;  { 1 GB/s cap }
  CNetFallbackBps = 12.5 * 1024.0 * 1024.0;   { 100 Mbps }
  CPeakDecay = 0.9975;                        { per frame ~15 fps; half of former 0.5%/frame }
  CLogRefBps = 100.0 * 1024.0;                { 100 KiB/s; log scale reference K }

constructor TRangeEngine.Create;
begin
  inherited Create;
  FDiskMaxBps := CDiskMinBps;
  FNetMaxBps := CNetFallbackBps;
  FSpeedScale := ssLinear;
end;

function TRangeEngine.LinearNorm(ABps, ARangeMax: Double): Double;
begin
  if (ABps <= 0) or (ARangeMax <= 0) then
    Exit(0);
  Result := Clamp01(ABps / ARangeMax);
end;

function TRangeEngine.NetNorm(ABps, ARangeMax: Double): Double;
var
  Denom: Double;
begin
  if (ABps <= 0) or (ARangeMax <= 0) then
    Exit(0);
  if FSpeedScale = ssLog then
  begin
    Denom := Ln(1.0 + ARangeMax / CLogRefBps);
    if Denom <= 0 then
      Exit(0);
    Result := Clamp01(Ln(1.0 + ABps / CLogRefBps) / Denom);
  end
  else
    Result := LinearNorm(ABps, ARangeMax);
end;

procedure TRangeEngine.Observe(const ASnap: TMetricsSnapshot);
var
  Peak: Double;
begin
  Peak := ASnap.DiskReadBps;
  if ASnap.DiskWriteBps > Peak then
    Peak := ASnap.DiskWriteBps;

  if Peak > FDiskMaxBps then
    FDiskMaxBps := Peak
  else
    FDiskMaxBps := FDiskMaxBps * CPeakDecay;

  if FDiskMaxBps < CDiskMinBps then
    FDiskMaxBps := CDiskMinBps;
  if FDiskMaxBps > CDiskMaxCapBps then
    FDiskMaxBps := CDiskMaxCapBps;

  if ASnap.NetLinkSpeedBps > 0 then
    FNetMaxBps := ASnap.NetLinkSpeedBps
  else if FNetMaxBps <= 0 then
    FNetMaxBps := CNetFallbackBps;
end;

function TRangeEngine.DiskReadNorm(const ASnap: TMetricsSnapshot): Double;
begin
  Result := LinearNorm(ASnap.DiskReadBps, FDiskMaxBps);
end;

function TRangeEngine.DiskWriteNorm(const ASnap: TMetricsSnapshot): Double;
begin
  Result := LinearNorm(ASnap.DiskWriteBps, FDiskMaxBps);
end;

function TRangeEngine.NetInNorm(const ASnap: TMetricsSnapshot): Double;
begin
  Result := NetNorm(ASnap.NetInBps, FNetMaxBps);
end;

function TRangeEngine.NetOutNorm(const ASnap: TMetricsSnapshot): Double;
begin
  Result := NetNorm(ASnap.NetOutBps, FNetMaxBps);
end;

end.
