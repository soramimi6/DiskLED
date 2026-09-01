unit uMeterRenderer;

interface

uses
  Vcl.Graphics,
  uLayoutTypes,
  uAssetStore,
  uMetricsTypes;

type
  TVisualFingerprint = record
    Cpu: Integer;
    Mem: Integer;
    Swap: Integer;
    DiskReadMeter: Integer;
    DiskWriteMeter: Integer;
    NetInMeter: Integer;
    NetOutMeter: Integer;
    Audio: Integer;
    AudioL: Integer;
    AudioR: Integer;
    DiskReadOn: Boolean;
    DiskWriteOn: Boolean;
    DiskRWOn: Boolean;
    NetInOn: Boolean;
    NetOutOn: Boolean;
    NetActivityOn: Boolean;
    PingLevel: TPingLevel;
    CpuPct: Integer;
    MemPct: Integer;
    SwapPct: Integer;
    GraphGen: Cardinal;
  end;

  TMeterRenderer = class
  public
    class function StripFrame(const AStrip: TSpriteStrip; AValue: Double): Integer; static;
    class function Fingerprint(const ALayout: TViewLayout; const AState: TDisplayState;
      AGraphGen: Cardinal): TVisualFingerprint; static;
    class function SameFingerprint(const A, B: TVisualFingerprint): Boolean; static;
    class procedure DrawBackground(ADest: TCanvas; const ALayout: TViewLayout;
      AAssets: TAssetStore); static;
    class procedure DrawMeters(ADest: TCanvas; const ALayout: TViewLayout;
      AAssets: TAssetStore; const AState: TDisplayState); static;
  end;

implementation

uses
  Winapi.Windows,
  uDigitRenderer;

class function TMeterRenderer.StripFrame(const AStrip: TSpriteStrip; AValue: Double): Integer;
begin
  if (AStrip.FileName = '') or (AStrip.Frames <= 0) then
    Exit(0);
  Result := Integer(Round(Clamp01(AValue) * (AStrip.Frames - 1)));
  if Result < 0 then
    Result := 0;
  if Result > AStrip.Frames - 1 then
    Result := AStrip.Frames - 1;
end;

function DigitPct(const AVal: TDigitValue; AValue01: Double): Integer;
begin
  if not AVal.Enabled then
    Exit(0);
  Result := Integer(Round(Clamp01(AValue01) * 100.0));
end;

function VisibleLed(const AStrip: TSpriteStrip; AOn: Boolean): Boolean;
begin
  if (AStrip.FileName = '') or (AStrip.Frames <= 0) then
    Exit(False);
  Result := AOn;
end;

class function TMeterRenderer.Fingerprint(const ALayout: TViewLayout;
  const AState: TDisplayState; AGraphGen: Cardinal): TVisualFingerprint;
begin
  Result.Cpu := StripFrame(ALayout.Cpu, AState.Cpu);
  Result.Mem := StripFrame(ALayout.Mem, AState.Mem);
  Result.Swap := StripFrame(ALayout.Swap, AState.Swap);
  Result.DiskReadMeter := StripFrame(ALayout.DiskReadMeter, AState.DiskRead);
  Result.DiskWriteMeter := StripFrame(ALayout.DiskWriteMeter, AState.DiskWrite);
  Result.NetInMeter := StripFrame(ALayout.NetInMeter, AState.NetIn);
  Result.NetOutMeter := StripFrame(ALayout.NetOutMeter, AState.NetOut);
  Result.Audio := StripFrame(ALayout.Audio, AState.Audio);
  Result.AudioL := StripFrame(ALayout.AudioL, AState.AudioL);
  Result.AudioR := StripFrame(ALayout.AudioR, AState.AudioR);
  Result.DiskReadOn := VisibleLed(ALayout.DiskRead, AState.DiskReadOn);
  Result.DiskWriteOn := VisibleLed(ALayout.DiskWrite, AState.DiskWriteOn);
  Result.DiskRWOn := VisibleLed(ALayout.DiskRW, AState.DiskRWOn);
  Result.NetInOn := VisibleLed(ALayout.NetIn, AState.NetInOn);
  Result.NetOutOn := VisibleLed(ALayout.NetOut, AState.NetOutOn);
  Result.NetActivityOn := VisibleLed(ALayout.NetActivity, AState.NetActivityOn) or
    VisibleLed(ALayout.NetTotal, AState.NetActivityOn);
  if (ALayout.Ping.FileName <> '') and (ALayout.Ping.Frames > 0) then
    Result.PingLevel := AState.PingLevel
  else
    Result.PingLevel := plTimeout;
  Result.CpuPct := DigitPct(ALayout.CpuVal, AState.CpuDigit);
  Result.MemPct := DigitPct(ALayout.MemVal, AState.MemDigit);
  Result.SwapPct := DigitPct(ALayout.SwapVal, AState.SwapDigit);
  Result.GraphGen := AGraphGen;
end;

class function TMeterRenderer.SameFingerprint(const A, B: TVisualFingerprint): Boolean;
begin
  Result :=
    (A.Cpu = B.Cpu) and (A.Mem = B.Mem) and (A.Swap = B.Swap) and
    (A.DiskReadMeter = B.DiskReadMeter) and (A.DiskWriteMeter = B.DiskWriteMeter) and
    (A.NetInMeter = B.NetInMeter) and (A.NetOutMeter = B.NetOutMeter) and
    (A.Audio = B.Audio) and (A.AudioL = B.AudioL) and (A.AudioR = B.AudioR) and
    (A.DiskReadOn = B.DiskReadOn) and (A.DiskWriteOn = B.DiskWriteOn) and
    (A.DiskRWOn = B.DiskRWOn) and
    (A.NetInOn = B.NetInOn) and (A.NetOutOn = B.NetOutOn) and
    (A.NetActivityOn = B.NetActivityOn) and
    (A.PingLevel = B.PingLevel) and
    (A.CpuPct = B.CpuPct) and (A.MemPct = B.MemPct) and (A.SwapPct = B.SwapPct) and
    (A.GraphGen = B.GraphGen);
end;

class procedure TMeterRenderer.DrawBackground(ADest: TCanvas; const ALayout: TViewLayout;
  AAssets: TAssetStore);
var
  Bg: Vcl.Graphics.TBitmap;
begin
  Bg := AAssets.Background(ALayout);
  ADest.Draw(0, 0, Bg);
end;

procedure DrawStrip(ADest: TCanvas; const ALayout: TViewLayout; AAssets: TAssetStore;
  const AStrip: TSpriteStrip; AValue: Double);
var
  Bmp: Vcl.Graphics.TBitmap;
  Frame: Integer;
  FrameH: Integer;
  SrcY: Integer;
begin
  if AStrip.FileName = '' then
    Exit;
  if AStrip.Frames <= 0 then
    Exit;

  Bmp := AAssets.Graphic(ALayout, AStrip.FileName);
  FrameH := Bmp.Height div AStrip.Frames;
  if FrameH <= 0 then
    Exit;

  Frame := TMeterRenderer.StripFrame(AStrip, AValue);
  SrcY := Frame * FrameH;

  if AStrip.Transparent then
    TransparentBlt(ADest.Handle, AStrip.X, AStrip.Y, Bmp.Width, FrameH,
      Bmp.Canvas.Handle, 0, SrcY, Bmp.Width, FrameH, ColorToRGB(AStrip.MaskColor))
  else
    BitBlt(ADest.Handle, AStrip.X, AStrip.Y, Bmp.Width, FrameH,
      Bmp.Canvas.Handle, 0, SrcY, SRCCOPY);
end;

procedure DrawLed(ADest: TCanvas; const ALayout: TViewLayout; AAssets: TAssetStore;
  const AStrip: TSpriteStrip; AOn: Boolean);
begin
  if AOn then
    DrawStrip(ADest, ALayout, AAssets, AStrip, 1.0)
  else
    DrawStrip(ADest, ALayout, AAssets, AStrip, 0.0);
end;

procedure DrawPing(ADest: TCanvas; const ALayout: TViewLayout; AAssets: TAssetStore;
  const AStrip: TSpriteStrip; ALevel: TPingLevel);
var
  Bmp: Vcl.Graphics.TBitmap;
  Frame: Integer;
  FrameH: Integer;
  SrcY: Integer;
begin
  if AStrip.FileName = '' then
    Exit;
  if AStrip.Frames <= 0 then
    Exit;

  Bmp := AAssets.Graphic(ALayout, AStrip.FileName);
  FrameH := Bmp.Height div AStrip.Frames;
  if FrameH <= 0 then
    Exit;

  { Frames: Timeout → Slow → Fair → Normal = 0..3 }
  Frame := Ord(ALevel);
  if Frame < 0 then
    Frame := 0;
  if Frame > AStrip.Frames - 1 then
    Frame := AStrip.Frames - 1;
  SrcY := Frame * FrameH;

  if AStrip.Transparent then
    TransparentBlt(ADest.Handle, AStrip.X, AStrip.Y, Bmp.Width, FrameH,
      Bmp.Canvas.Handle, 0, SrcY, Bmp.Width, FrameH, ColorToRGB(AStrip.MaskColor))
  else
    BitBlt(ADest.Handle, AStrip.X, AStrip.Y, Bmp.Width, FrameH,
      Bmp.Canvas.Handle, 0, SrcY, SRCCOPY);
end;

class procedure TMeterRenderer.DrawMeters(ADest: TCanvas; const ALayout: TViewLayout;
  AAssets: TAssetStore; const AState: TDisplayState);
begin
  DrawStrip(ADest, ALayout, AAssets, ALayout.Cpu, AState.Cpu);
  DrawStrip(ADest, ALayout, AAssets, ALayout.Mem, AState.Mem);
  DrawStrip(ADest, ALayout, AAssets, ALayout.Swap, AState.Swap);

  DrawStrip(ADest, ALayout, AAssets, ALayout.DiskReadMeter, AState.DiskRead);
  DrawStrip(ADest, ALayout, AAssets, ALayout.DiskWriteMeter, AState.DiskWrite);
  DrawStrip(ADest, ALayout, AAssets, ALayout.NetInMeter, AState.NetIn);
  DrawStrip(ADest, ALayout, AAssets, ALayout.NetOutMeter, AState.NetOut);
  DrawStrip(ADest, ALayout, AAssets, ALayout.Audio, AState.Audio);
  DrawStrip(ADest, ALayout, AAssets, ALayout.AudioL, AState.AudioL);
  DrawStrip(ADest, ALayout, AAssets, ALayout.AudioR, AState.AudioR);

  DrawLed(ADest, ALayout, AAssets, ALayout.DiskRead, AState.DiskReadOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.DiskWrite, AState.DiskWriteOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.DiskRW, AState.DiskRWOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.NetActivity, AState.NetActivityOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.NetIn, AState.NetInOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.NetOut, AState.NetOutOn);
  DrawLed(ADest, ALayout, AAssets, ALayout.NetTotal, AState.NetActivityOn);

  DrawPing(ADest, ALayout, AAssets, ALayout.Ping, AState.PingLevel);

  TDigitRenderer.DrawPercent(ADest, ALayout, AAssets, ALayout.CpuVal, AState.CpuDigit);
  TDigitRenderer.DrawPercent(ADest, ALayout, AAssets, ALayout.MemVal, AState.MemDigit);
  TDigitRenderer.DrawPercent(ADest, ALayout, AAssets, ALayout.SwapVal, AState.SwapDigit);
end;

end.
