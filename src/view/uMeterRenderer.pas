unit uMeterRenderer;

interface

uses
  Vcl.Graphics,
  uLayoutTypes,
  uAssetStore,
  uMetricsTypes;

type
  TMeterRenderer = class
  public
    class procedure DrawBackground(ADest: TCanvas; const ALayout: TViewLayout;
      AAssets: TAssetStore); static;
    class procedure DrawMeters(ADest: TCanvas; const ALayout: TViewLayout;
      AAssets: TAssetStore; const AState: TDisplayState); static;
  end;

implementation

uses
  Winapi.Windows,
  uDigitRenderer;

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

  Frame := Integer(Round(Clamp01(AValue) * (AStrip.Frames - 1)));
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
