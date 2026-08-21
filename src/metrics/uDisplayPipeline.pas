unit uDisplayPipeline;

interface

uses
  uMetricsTypes,
  uRangeEngine;

type
  TDisplayPipeline = class
  private
    FState: TDisplayState;
    FRange: TRangeEngine;
    FFactor: Double;
    FStartupTick: Cardinal;
    FStartupDone: Boolean;
    FHasStartupTick: Boolean;
    FDigitTick: Cardinal;
    FHasDigitTick: Boolean;
    function Follow(ACurrent, ATarget: Double): Double;
    function StartupProgress: Double;
    procedure RefreshDigits(AForce: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Update(const ASnap: TMetricsSnapshot);
    property State: TDisplayState read FState;
  end;

implementation

uses
  Winapi.Windows;

const
  CStartupDurationMs = 900;
  { Numeric readout only — meters/LEDs keep full frame rate. }
  CDigitIntervalMs = 1000;

constructor TDisplayPipeline.Create;
begin
  inherited Create;
  { Per-frame exponential ease toward the sample (not raw, not constant-speed linear). }
  FFactor := 0.32;
  FStartupDone := False;
  FHasStartupTick := False;
  FHasDigitTick := False;
  FRange := TRangeEngine.Create;
end;

destructor TDisplayPipeline.Destroy;
begin
  FRange.Free;
  inherited;
end;

function TDisplayPipeline.Follow(ACurrent, ATarget: Double): Double;
begin
  Result := ACurrent + (ATarget - ACurrent) * FFactor;
  if Abs(Result - ATarget) < 0.004 then
    Result := ATarget;
  Result := Clamp01(Result);
end;

function TDisplayPipeline.StartupProgress: Double;
var
  Elapsed: Cardinal;
begin
  if not FHasStartupTick then
  begin
    FStartupTick := GetTickCount;
    FHasStartupTick := True;
  end;

  Elapsed := GetTickCount - FStartupTick;
  if Elapsed >= CStartupDurationMs then
  begin
    FStartupDone := True;
    Result := 1.0;
  end
  else
    Result := Elapsed / CStartupDurationMs;
end;

procedure TDisplayPipeline.RefreshDigits(AForce: Boolean);
var
  NowTick: Cardinal;
begin
  NowTick := GetTickCount;
  if (not AForce) and FHasDigitTick and ((NowTick - FDigitTick) < CDigitIntervalMs) then
    Exit;

  FState.CpuDigit := FState.Cpu;
  FState.MemDigit := FState.Mem;
  FState.SwapDigit := FState.Swap;
  FDigitTick := NowTick;
  FHasDigitTick := True;
end;

procedure TDisplayPipeline.Update(const ASnap: TMetricsSnapshot);
var
  CpuT, MemT, SwapT: Double;
  DiskRT, DiskWT, NetIT, NetOT: Double;
  Progress: Double;
begin
  FRange.Observe(ASnap);

  CpuT := Clamp01(ASnap.CpuUsage / 100.0);
  MemT := Clamp01(ASnap.MemUsage / 100.0);
  SwapT := Clamp01(ASnap.SwapUsage / 100.0);
  DiskRT := FRange.DiskReadNorm(ASnap);
  DiskWT := FRange.DiskWriteNorm(ASnap);
  NetIT := FRange.NetInNorm(ASnap);
  NetOT := FRange.NetOutNorm(ASnap);

  FState.DiskReadOn := IsActiveBps(ASnap.DiskReadBps);
  FState.DiskWriteOn := IsActiveBps(ASnap.DiskWriteBps);
  FState.DiskRWOn := FState.DiskReadOn or FState.DiskWriteOn;
  FState.NetInOn := IsActiveBps(ASnap.NetInBps);
  FState.NetOutOn := IsActiveBps(ASnap.NetOutBps);
  FState.NetActivityOn := FState.NetInOn or FState.NetOutOn;
  FState.PingPending := ASnap.PingPending;
  { Ping level is discrete — no smoothing; keep prior while pending. }
  if not ASnap.PingPending then
    FState.PingLevel := ASnap.PingLevel;

  if not FStartupDone then
  begin
    Progress := StartupProgress;
    FState.Cpu := Clamp01(CpuT * Progress);
    FState.Mem := Clamp01(MemT * Progress);
    FState.Swap := Clamp01(SwapT * Progress);
    FState.DiskRead := Clamp01(DiskRT * Progress);
    FState.DiskWrite := Clamp01(DiskWT * Progress);
    FState.NetIn := Clamp01(NetIT * Progress);
    FState.NetOut := Clamp01(NetOT * Progress);
    RefreshDigits(True);
    Exit;
  end;

  FState.Cpu := Follow(FState.Cpu, CpuT);
  FState.Mem := Follow(FState.Mem, MemT);
  FState.Swap := Follow(FState.Swap, SwapT);
  FState.DiskRead := Follow(FState.DiskRead, DiskRT);
  FState.DiskWrite := Follow(FState.DiskWrite, DiskWT);
  FState.NetIn := Follow(FState.NetIn, NetIT);
  FState.NetOut := Follow(FState.NetOut, NetOT);

  RefreshDigits(False);
end;

end.
