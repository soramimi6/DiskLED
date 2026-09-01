unit uDisplayPipeline;

interface

uses
  uMetricsTypes,
  uRangeEngine;

type
  TMeterFollowDir = (mfdNone, mfdUp, mfdDown);

  TDisplayPipeline = class
  private
    FState: TDisplayState;
    FNormalized: TNormalizedMetrics;
    FRange: TRangeEngine;
    FBallistics: TMeterBallistics;
    FDirCpu: TMeterFollowDir;
    FDirMem: TMeterFollowDir;
    FDirSwap: TMeterFollowDir;
    FDirDiskRead: TMeterFollowDir;
    FDirDiskWrite: TMeterFollowDir;
    FDirNetIn: TMeterFollowDir;
    FDirNetOut: TMeterFollowDir;
    FDirAudio: TMeterFollowDir;
    FDirAudioL: TMeterFollowDir;
    FDirAudioR: TMeterFollowDir;
    FFollowTick: Cardinal;
    FHasFollowTick: Boolean;
    FStartupTick: Cardinal;
    FStartupDone: Boolean;
    FHasStartupTick: Boolean;
    FDigitTick: Cardinal;
    FHasDigitTick: Boolean;
    FLastSnap: TMetricsSnapshot;
    function AttackTau(const AParams: TBallisticParams): Double;
    function FallSpeedOf(AKind: TBallisticKind): Double;
    function Follow(ACurrent, ATarget: Double; const AParams: TBallisticParams;
      var ADir: TMeterFollowDir; ADtSec: Double): Double;
    function StartupProgress: Double;
    procedure RefreshDigits(AForce: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ApplyBallistics(const ABallistics: TMeterBallistics);
    function ApplySpeedScale(AScale: TSpeedScale): Boolean;
    procedure Update(const ASnap: TMetricsSnapshot);
    property State: TDisplayState read FState;
    property Normalized: TNormalizedMetrics read FNormalized;
    property LastSnap: TMetricsSnapshot read FLastSnap;
  end;

implementation

uses
  System.Math,
  Winapi.Windows;

const
  CStartupDurationMs = 900;
  { Numeric readout only — meters/LEDs keep full frame rate. }
  CDigitIntervalMs = 1000;
  CMaxDtSec = 0.25;
  CDeadband = 0.01;
  CRiseSnap = 0.004;

  CVuTauSlow = 0.14;
  CVuTauFast = 0.035;
  CBarTauSlow = 0.20;
  CBarTauFast = 0.05;
  CPeakTauSlow = 0.07;
  CPeakTauFast = 0.018;

  CVuFallPerSec = 1.25;
  CBarFallPerSec = 2.0;
  CPeakFallPerSec = 0.77;

constructor TDisplayPipeline.Create;
begin
  inherited Create;
  FBallistics := DefaultMeterBallistics;
  FStartupDone := False;
  FHasStartupTick := False;
  FHasDigitTick := False;
  FHasFollowTick := False;
  FRange := TRangeEngine.Create;
end;

destructor TDisplayPipeline.Destroy;
begin
  FRange.Free;
  inherited;
end;

procedure TDisplayPipeline.ApplyBallistics(const ABallistics: TMeterBallistics);
begin
  FBallistics := ABallistics;
  FBallistics.Cpu.Strength := ClampStrength(FBallistics.Cpu.Strength);
  FBallistics.Mem.Strength := ClampStrength(FBallistics.Mem.Strength);
  FBallistics.Swap.Strength := ClampStrength(FBallistics.Swap.Strength);
  FBallistics.DiskRead.Strength := ClampStrength(FBallistics.DiskRead.Strength);
  FBallistics.DiskWrite.Strength := ClampStrength(FBallistics.DiskWrite.Strength);
  FBallistics.NetIn.Strength := ClampStrength(FBallistics.NetIn.Strength);
  FBallistics.NetOut.Strength := ClampStrength(FBallistics.NetOut.Strength);
  FBallistics.Audio.Strength := ClampStrength(FBallistics.Audio.Strength);
  FBallistics.AudioL.Strength := ClampStrength(FBallistics.AudioL.Strength);
  FBallistics.AudioR.Strength := ClampStrength(FBallistics.AudioR.Strength);
end;

function TDisplayPipeline.ApplySpeedScale(AScale: TSpeedScale): Boolean;
begin
  Result := False;
  if FRange = nil then
    Exit;
  if FRange.SpeedScale = AScale then
    Exit;
  FRange.SpeedScale := AScale;
  Result := True;
end;

function TDisplayPipeline.AttackTau(const AParams: TBallisticParams): Double;
var
  Slow, Fast, T: Double;
begin
  case AParams.Kind of
    bkBar:
      begin
        Slow := CBarTauSlow;
        Fast := CBarTauFast;
      end;
    bkPeak:
      begin
        Slow := CPeakTauSlow;
        Fast := CPeakTauFast;
      end;
  else
    Slow := CVuTauSlow;
    Fast := CVuTauFast;
  end;
  T := ClampStrength(AParams.Strength) / 100.0;
  Result := Fast + (Slow - Fast) * (1.0 - T);
  if Result < 0.001 then
    Result := 0.001;
end;

function TDisplayPipeline.FallSpeedOf(AKind: TBallisticKind): Double;
begin
  case AKind of
    bkBar: Result := CBarFallPerSec;
    bkPeak: Result := CPeakFallPerSec;
  else
    Result := CVuFallPerSec;
  end;
end;

function TDisplayPipeline.Follow(ACurrent, ATarget: Double;
  const AParams: TBallisticParams; var ADir: TMeterFollowDir; ADtSec: Double): Double;
var
  Diff: Double;
  K: Double;
  Tau: Double;
begin
  Diff := ATarget - ACurrent;
  if Abs(Diff) >= CDeadband then
  begin
    if Diff > 0 then
      ADir := mfdUp
    else
      ADir := mfdDown;
  end;

  if ADir = mfdDown then
  begin
    Result := ACurrent - FallSpeedOf(AParams.Kind) * ADtSec;
    if Result < ATarget then
      Result := ATarget;
  end
  else
  begin
    Tau := AttackTau(AParams);
    K := 1.0 - Exp(-ADtSec / Tau);
    if K < 0 then
      K := 0;
    if K > 1 then
      K := 1;
    Result := ACurrent + (ATarget - ACurrent) * K;
    if Abs(Result - ATarget) < CRiseSnap then
      Result := ATarget;
  end;
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
  DiskRT, DiskWT, NetIT, NetOT, AudioT, AudioLT, AudioRT: Double;
  Progress: Double;
  NowTick: Cardinal;
  DtSec: Double;
begin
  FRange.Observe(ASnap);
  FLastSnap := ASnap;

  CpuT := Clamp01(ASnap.CpuUsage / 100.0);
  MemT := Clamp01(ASnap.MemUsage / 100.0);
  SwapT := Clamp01(ASnap.SwapUsage / 100.0);
  DiskRT := FRange.DiskReadNorm(ASnap);
  DiskWT := FRange.DiskWriteNorm(ASnap);
  NetIT := FRange.NetInNorm(ASnap);
  NetOT := FRange.NetOutNorm(ASnap);
  AudioT := Clamp01(ASnap.AudioPeak);
  AudioLT := Clamp01(ASnap.AudioPeakL);
  AudioRT := Clamp01(ASnap.AudioPeakR);

  FNormalized.Cpu := CpuT;
  FNormalized.Mem := MemT;
  FNormalized.Swap := SwapT;
  FNormalized.DiskRead := DiskRT;
  FNormalized.DiskWrite := DiskWT;
  FNormalized.NetIn := NetIT;
  FNormalized.NetOut := NetOT;
  FNormalized.Audio := AudioT;
  FNormalized.AudioL := AudioLT;
  FNormalized.AudioR := AudioRT;

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

  NowTick := GetTickCount;
  if not FHasFollowTick then
    DtSec := 1.0 / 15.0
  else
  begin
    DtSec := (NowTick - FFollowTick) / 1000.0;
    if DtSec < 0 then
      DtSec := 0;
    if DtSec > CMaxDtSec then
      DtSec := CMaxDtSec;
  end;
  FFollowTick := NowTick;
  FHasFollowTick := True;

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
    FState.Audio := Clamp01(AudioT * Progress);
    FState.AudioL := Clamp01(AudioLT * Progress);
    FState.AudioR := Clamp01(AudioRT * Progress);
    RefreshDigits(True);
    Exit;
  end;

  FState.Cpu := Follow(FState.Cpu, CpuT, FBallistics.Cpu, FDirCpu, DtSec);
  FState.Mem := Follow(FState.Mem, MemT, FBallistics.Mem, FDirMem, DtSec);
  FState.Swap := Follow(FState.Swap, SwapT, FBallistics.Swap, FDirSwap, DtSec);
  FState.DiskRead := Follow(FState.DiskRead, DiskRT, FBallistics.DiskRead, FDirDiskRead, DtSec);
  FState.DiskWrite := Follow(FState.DiskWrite, DiskWT, FBallistics.DiskWrite, FDirDiskWrite, DtSec);
  FState.NetIn := Follow(FState.NetIn, NetIT, FBallistics.NetIn, FDirNetIn, DtSec);
  FState.NetOut := Follow(FState.NetOut, NetOT, FBallistics.NetOut, FDirNetOut, DtSec);
  FState.Audio := Follow(FState.Audio, AudioT, FBallistics.Audio, FDirAudio, DtSec);
  FState.AudioL := Follow(FState.AudioL, AudioLT, FBallistics.AudioL, FDirAudioL, DtSec);
  FState.AudioR := Follow(FState.AudioR, AudioRT, FBallistics.AudioR, FDirAudioR, DtSec);

  RefreshDigits(False);
end;

end.
