unit uGraphRenderer;

{ Draws history polylines: 1 horizontal pixel = 1 sample. }

interface

uses
  Vcl.Graphics,
  uLayoutTypes,
  uHistoryBuffer;

type
  TGraphRenderer = class
  public
    class procedure Draw(ACanvas: TCanvas; const AGraph: TGraphLayout;
      AHistory: THistoryBuffer); static;
  end;

implementation

uses
  System.Types,
  uMetricsTypes;

type
  TLaneKind = (lkCpu, lkMem, lkSwap, lkDiskRead, lkDiskWrite, lkNetIn, lkNetOut);

class procedure TGraphRenderer.Draw(ACanvas: TCanvas; const AGraph: TGraphLayout;
  AHistory: THistoryBuffer);

  function SampleValue(const S: THistorySample; AKind: TLaneKind): Double;
  begin
    case AKind of
      lkCpu: Result := S.Cpu;
      lkMem: Result := S.Mem;
      lkSwap: Result := S.Swap;
      lkDiskRead: Result := S.DiskRead;
      lkDiskWrite: Result := S.DiskWrite;
      lkNetIn: Result := S.NetIn;
    else
      Result := S.NetOut;
    end;
  end;

  procedure DrawLane(const ALane: TGraphLane; AKind: TLaneKind);
  var
    i, Cap, W, Start, X, Y: Integer;
    R: TRect;
    V: Double;
  begin
    if (not ALane.Enabled) or (ALane.W < 1) or (ALane.H < 1) then
      Exit;
    if AHistory = nil then
      Exit;
    Cap := AHistory.Capacity;
    if Cap < 1 then
      Exit;

    W := ALane.W;
    if W > Cap then
      W := Cap;
    Start := Cap - W;

    R := Rect(ALane.X, ALane.Y, ALane.X + ALane.W, ALane.Y + ALane.H);
    ACanvas.Pen.Color := ALane.Color;
    ACanvas.Pen.Width := 1;
    ACanvas.Brush.Style := bsClear;

    for i := 0 to W - 1 do
    begin
      V := Clamp01(SampleValue(AHistory.SampleChronological(Start + i), AKind));
      X := R.Left + i;
      Y := R.Bottom - 1 - Round(V * (R.Height - 1));
      if i = 0 then
        ACanvas.MoveTo(X, Y)
      else
        ACanvas.LineTo(X, Y);
    end;
  end;

begin
  if not AGraph.Enabled then
    Exit;
  DrawLane(AGraph.Cpu, lkCpu);
  DrawLane(AGraph.Mem, lkMem);
  DrawLane(AGraph.Swap, lkSwap);
  DrawLane(AGraph.DiskRead, lkDiskRead);
  DrawLane(AGraph.DiskWrite, lkDiskWrite);
  DrawLane(AGraph.NetIn, lkNetIn);
  DrawLane(AGraph.NetOut, lkNetOut);
end;

end.
