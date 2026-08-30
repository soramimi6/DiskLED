unit uDashboardGraph;

interface

uses
  System.Types,
  Vcl.Graphics,
  uDashboardHistory,
  uDashboardTheme;

type
  TDashLineStyle = (lsSolid, lsDash);

procedure InitDashboardGraph;
procedure FinalizeDashboardGraph;
function DashboardGraphReady: Boolean;

procedure DrawMetricGraph(ACanvas: TCanvas; const ARect: TRect;
  AHistory: TDashboardHistory; ALane: TDashboardLane; AColor: TColor;
  AMaxY: Double; ALineStyle: TDashLineStyle; const APalette: THudPalette;
  const AMetrics: THudMetrics; const AAxisNow, AAxis5m: string);
procedure DrawOverlayMetricGraph(ACanvas: TCanvas; const ARect: TRect;
  AHistory: TDashboardHistory; ALane1: TDashboardLane; AColor1: TColor;
  AStyle1: TDashLineStyle; ALane2: TDashboardLane; AColor2: TColor;
  AStyle2: TDashLineStyle; AMaxY: Double; const APalette: THudPalette;
  const AMetrics: THudMetrics; const AAxisNow, AAxis5m: string);
procedure DrawConcentricMeter(ACanvas: TCanvas; const ARect: TRect;
  ALevel: Double; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawDualConcentricMeter(ACanvas: TCanvas; const ARect: TRect;
  AOuterLevel, AInnerLevel: Double; AOuterAccent, AInnerAccent: TColor;
  const APalette: THudPalette; const AMetrics: THudMetrics);

implementation

uses
  System.SysUtils,
  System.UITypes,
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  uMetricsTypes;

var
  GGdiToken: ULONG_PTR;
  GGdiOk: Boolean;

procedure InitDashboardGraph;
var
  Input: TGdiplusStartupInput;
begin
  if GGdiOk then
    Exit;
  FillChar(Input, SizeOf(Input), 0);
  Input.GdiplusVersion := 1;
  GGdiOk := GdiplusStartup(GGdiToken, @Input, nil) = Ok;
end;

procedure FinalizeDashboardGraph;
begin
  if GGdiOk then
  begin
    GdiplusShutdown(GGdiToken);
    GGdiOk := False;
  end;
end;

function DashboardGraphReady: Boolean;
begin
  Result := GGdiOk;
end;

function GraphDip(const AMetrics: THudMetrics; V: Integer): Integer;
begin
  Result := MulDiv(V, AMetrics.Margin, 12);
  if (V > 0) and (Result < 1) then
    Result := 1;
end;

procedure DrawGridGdi(AGraphics: TGPGraphics; const ARect: TRect;
  AColor: TColor; APenWidth: Integer);
var
  Pen: TGPPen;
  Y: Single;
  i: Integer;
begin
  if APenWidth < 1 then
    APenWidth := 1;
  Pen := TGPPen.Create(MakeColor(255, GetRValue(AColor), GetGValue(AColor),
    GetBValue(AColor)), APenWidth);
  try
    Pen.SetDashStyle(DashStyleDot);
    for i := 1 to 3 do
    begin
      Y := ARect.Top + (ARect.Height * i / 4.0);
      AGraphics.DrawLine(Pen, Single(ARect.Left), Y, Single(ARect.Right), Y);
    end;
  finally
    Pen.Free;
  end;
end;

procedure DrawLineGdi(AGraphics: TGPGraphics; const ARect: TRect;
  AHistory: TDashboardHistory; ALane: TDashboardLane; AColor: TColor;
  AMaxY: Double; ALineStyle: TDashLineStyle; AFillUnder: Boolean;
  AFillAlpha: Byte; APenWidth: Integer);
var
  Count, i: Integer;
  Points, FillPts: array of TGPPointF;
  Pen: TGPPen;
  Brush: TGPSolidBrush;
  V: Single;
  R, G, B: Byte;
begin
  if (AHistory = nil) or (AHistory.Count < 2) then
    Exit;
  Count := AHistory.Count;
  SetLength(Points, Count);
  for i := 0 to Count - 1 do
  begin
    V := AHistory.LaneValue(ALane, i);
    if AMaxY > 0 then
      V := V / AMaxY;
    if V < 0 then V := 0;
    if V > 1 then V := 1;
    Points[i].X := ARect.Left + (ARect.Width * i / (Count - 1));
    Points[i].Y := ARect.Bottom - (ARect.Height * V);
  end;
  R := GetRValue(AColor);
  G := GetGValue(AColor);
  B := GetBValue(AColor);
  if AFillUnder then
  begin
    SetLength(FillPts, Count + 2);
    Move(Points[0], FillPts[0], Count * SizeOf(TGPPointF));
    FillPts[Count].X := Points[Count - 1].X;
    FillPts[Count].Y := ARect.Bottom;
    FillPts[Count + 1].X := Points[0].X;
    FillPts[Count + 1].Y := ARect.Bottom;
    Brush := TGPSolidBrush.Create(MakeColor(AFillAlpha, R, G, B));
    try
      AGraphics.FillPolygon(Brush, PGPPointF(@FillPts[0]), Count + 2);
    finally
      Brush.Free;
    end;
  end;
  if APenWidth < 1 then
    APenWidth := 1;
  Pen := TGPPen.Create(MakeColor(255, R, G, B), APenWidth);
  try
    if ALineStyle = lsDash then
      Pen.SetDashStyle(DashStyleDash);
    AGraphics.DrawLines(Pen, PGPPointF(@Points[0]), Count);
  finally
    Pen.Free;
  end;
end;

procedure DrawLineGdiFallback(ACanvas: TCanvas; const ARect: TRect;
  AHistory: TDashboardHistory; ALane: TDashboardLane; AColor: TColor;
  AMaxY: Double; AFillUnder: Boolean; AFillAlpha: Byte; APenWidth: Integer);
var
  Count, i: Integer;
  X, Y, V: Single;
  Poly: array of TPoint;
  FillC, BaseC: TColor;
begin
  if (AHistory = nil) or (AHistory.Count < 2) then
    Exit;
  Count := AHistory.Count;
  if AFillUnder then
  begin
    SetLength(Poly, Count + 2);
    for i := 0 to Count - 1 do
    begin
      V := AHistory.LaneValue(ALane, i);
      if AMaxY > 0 then
        V := V / AMaxY;
      if V < 0 then V := 0;
      if V > 1 then V := 1;
      Poly[i].X := Round(ARect.Left + (ARect.Width * i / (Count - 1)));
      Poly[i].Y := Round(ARect.Bottom - (ARect.Height * V));
    end;
    Poly[Count].X := Poly[Count - 1].X;
    Poly[Count].Y := ARect.Bottom;
    Poly[Count + 1].X := Poly[0].X;
    Poly[Count + 1].Y := ARect.Bottom;
    BaseC := ACanvas.Brush.Color;
    FillC := RGB(
      (GetRValue(AColor) * AFillAlpha + GetRValue(BaseC) * (255 - AFillAlpha)) div 255,
      (GetGValue(AColor) * AFillAlpha + GetGValue(BaseC) * (255 - AFillAlpha)) div 255,
      (GetBValue(AColor) * AFillAlpha + GetBValue(BaseC) * (255 - AFillAlpha)) div 255);
    ACanvas.Brush.Color := FillC;
    ACanvas.Pen.Style := psClear;
    ACanvas.Polygon(Poly);
    ACanvas.Pen.Style := psSolid;
  end;
  ACanvas.Pen.Color := AColor;
  if APenWidth < 1 then
    APenWidth := 1;
  ACanvas.Pen.Width := APenWidth;
  ACanvas.Brush.Style := bsClear;
  for i := 0 to Count - 1 do
  begin
    V := AHistory.LaneValue(ALane, i);
    if AMaxY > 0 then
      V := V / AMaxY;
    if V < 0 then V := 0;
    if V > 1 then V := 1;
    X := ARect.Left + (ARect.Width * i / (Count - 1));
    Y := ARect.Bottom - (ARect.Height * V);
    if i = 0 then
      ACanvas.MoveTo(Round(X), Round(Y))
    else
      ACanvas.LineTo(Round(X), Round(Y));
  end;
end;

procedure DrawMetricGraph(ACanvas: TCanvas; const ARect: TRect;
  AHistory: TDashboardHistory; ALane: TDashboardLane; AColor: TColor;
  AMaxY: Double; ALineStyle: TDashLineStyle; const APalette: THudPalette;
  const AMetrics: THudMetrics; const AAxisNow, AAxis5m: string);
var
  Graphics: TGPGraphics;
  CanvasDc: HDC;
begin
  ACanvas.Brush.Color := APalette.Card;
  ACanvas.FillRect(ARect);

  if GGdiOk then
  begin
    CanvasDc := ACanvas.Handle;
    Graphics := TGPGraphics.Create(CanvasDc);
    try
      Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
      DrawGridGdi(Graphics, ARect, APalette.Grid, AMetrics.GraphPenWidth div 2);
      DrawLineGdi(Graphics, ARect, AHistory, ALane, AColor, AMaxY, ALineStyle, True,
        APalette.GraphFillAlpha, AMetrics.GraphPenWidth);
    finally
      Graphics.Free;
    end;
  end
  else
    DrawLineGdiFallback(ACanvas, ARect, AHistory, ALane, AColor, AMaxY, True,
      APalette.GraphFillAlpha, AMetrics.GraphPenWidth);

  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.PixelsPerInch := 96;
  ACanvas.Font.Size := AMetrics.AxisSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.Brush.Style := bsClear;
  SetBkMode(ACanvas.Handle, TRANSPARENT);
  ACanvas.TextOut(ARect.Left + GraphDip(AMetrics, 4), ARect.Bottom + GraphDip(AMetrics, 2),
    AAxis5m);
  ACanvas.TextOut(ARect.Right - ACanvas.TextWidth(AAxisNow) - GraphDip(AMetrics, 4),
    ARect.Bottom + GraphDip(AMetrics, 2), AAxisNow);
end;

procedure DrawOverlayMetricGraph(ACanvas: TCanvas; const ARect: TRect;
  AHistory: TDashboardHistory; ALane1: TDashboardLane; AColor1: TColor;
  AStyle1: TDashLineStyle; ALane2: TDashboardLane; AColor2: TColor;
  AStyle2: TDashLineStyle; AMaxY: Double; const APalette: THudPalette;
  const AMetrics: THudMetrics; const AAxisNow, AAxis5m: string);
var
  Graphics: TGPGraphics;
  CanvasDc: HDC;
begin
  ACanvas.Brush.Color := APalette.Card;
  ACanvas.FillRect(ARect);

  if GGdiOk then
  begin
    CanvasDc := ACanvas.Handle;
    Graphics := TGPGraphics.Create(CanvasDc);
    try
      Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
      DrawGridGdi(Graphics, ARect, APalette.Grid, AMetrics.GraphPenWidth div 2);
      DrawLineGdi(Graphics, ARect, AHistory, ALane1, AColor1, AMaxY, AStyle1, False, 0,
        AMetrics.GraphPenWidth);
      DrawLineGdi(Graphics, ARect, AHistory, ALane2, AColor2, AMaxY, AStyle2, False, 0,
        AMetrics.GraphPenWidth);
    finally
      Graphics.Free;
    end;
  end
  else
  begin
    DrawLineGdiFallback(ACanvas, ARect, AHistory, ALane1, AColor1, AMaxY, False, 0,
      AMetrics.GraphPenWidth);
    DrawLineGdiFallback(ACanvas, ARect, AHistory, ALane2, AColor2, AMaxY, False, 0,
      AMetrics.GraphPenWidth);
  end;

  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.PixelsPerInch := 96;
  ACanvas.Font.Size := AMetrics.AxisSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.Brush.Style := bsClear;
  SetBkMode(ACanvas.Handle, TRANSPARENT);
  ACanvas.TextOut(ARect.Left + GraphDip(AMetrics, 4), ARect.Bottom + GraphDip(AMetrics, 2),
    AAxis5m);
  ACanvas.TextOut(ARect.Right - ACanvas.TextWidth(AAxisNow) - GraphDip(AMetrics, 4),
    ARect.Bottom + GraphDip(AMetrics, 2), AAxisNow);
end;

procedure DrawConcentricMeterFallback(ACanvas: TCanvas; const ABox: TRect;
  ALevel: Double; AAccent: TColor; const APalette: THudPalette; APenW: Integer);
begin
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Width := APenW;
  ACanvas.Pen.Color := APalette.Grid;
  ACanvas.Ellipse(ABox.Left, ABox.Top, ABox.Right, ABox.Bottom);
  if ALevel > 0.002 then
  begin
    ACanvas.Pen.Color := AAccent;
    ACanvas.Arc(ABox.Left, ABox.Top, ABox.Right, ABox.Bottom,
      ABox.Left, (ABox.Top + ABox.Bottom) div 2,
      ABox.Left + Round((ABox.Right - ABox.Left) * ALevel), ABox.Top);
  end;
  ACanvas.Pen.Width := 1;
  ACanvas.Pen.Color := APalette.CardBorder;
  ACanvas.Ellipse(ABox.Left + APenW * 2, ABox.Top + APenW * 2,
    ABox.Right - APenW * 2, ABox.Bottom - APenW * 2);
end;

procedure DrawConcentricMeter(ACanvas: TCanvas; const ARect: TRect;
  ALevel: Double; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Graphics: TGPGraphics;
  Track, ValuePen, InnerPen: TGPPen;
  Box, Inner: TGPRectF;
  Side, PenW: Single;
  Level: Double;
  R: TRect;
  RectW, RectH, MinSide: Integer;
begin
  Level := Clamp01(ALevel);
  RectW := ARect.Right - ARect.Left;
  RectH := ARect.Bottom - ARect.Top;
  Side := RectW;
  if RectH < Side then
    Side := RectH;
  MinSide := AMetrics.MeterPenMin * 5;
  if MinSide < 24 then
    MinSide := 24;
  if Side < MinSide then
    Exit;
  R.Left := ARect.Left + Round((RectW - Side) / 2);
  R.Top := ARect.Top + Round((RectH - Side) / 2);
  R.Right := R.Left + Round(Side);
  R.Bottom := R.Top + Round(Side);
  PenW := Side * 0.12;
  if PenW < AMetrics.MeterPenMin then
    PenW := AMetrics.MeterPenMin;
  Box.X := R.Left + PenW * 0.5;
  Box.Y := R.Top + PenW * 0.5;
  Box.Width := Side - PenW;
  Box.Height := Side - PenW;
  Inner.X := Box.X + PenW * 1.6;
  Inner.Y := Box.Y + PenW * 1.6;
  Inner.Width := Box.Width - PenW * 3.2;
  Inner.Height := Box.Height - PenW * 3.2;

  if not GGdiOk then
  begin
    DrawConcentricMeterFallback(ACanvas, R, Level, AAccent, APalette, Round(PenW));
    Exit;
  end;

  Graphics := TGPGraphics.Create(ACanvas.Handle);
  Track := nil;
  ValuePen := nil;
  InnerPen := nil;
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    Track := TGPPen.Create(MakeColor(255, GetRValue(APalette.Grid),
      GetGValue(APalette.Grid), GetBValue(APalette.Grid)), PenW);
    Track.SetStartCap(LineCapRound);
    Track.SetEndCap(LineCapRound);
    Graphics.DrawArc(Track, Box, 135, 270);
    if Level > 0.002 then
    begin
      ValuePen := TGPPen.Create(MakeColor(255, GetRValue(AAccent),
        GetGValue(AAccent), GetBValue(AAccent)), PenW);
      ValuePen.SetStartCap(LineCapRound);
      ValuePen.SetEndCap(LineCapRound);
      Graphics.DrawArc(ValuePen, Box, 135, Single(270.0 * Level));
    end;
    if (Inner.Width > AMetrics.MeterPenMinInner * 2) and
      (Inner.Height > AMetrics.MeterPenMinInner * 2) then
    begin
      InnerPen := TGPPen.Create(MakeColor(255, GetRValue(APalette.CardBorder),
        GetGValue(APalette.CardBorder), GetBValue(APalette.CardBorder)), 1);
      Graphics.DrawEllipse(InnerPen, Inner);
    end;
  finally
    InnerPen.Free;
    ValuePen.Free;
    Track.Free;
    Graphics.Free;
  end;
end;

procedure DrawGaugeArc(AGraphics: TGPGraphics; const ABox: TGPRectF; APenW: Single;
  ALevel: Double; ATrack, AValue: TColor);
var
  Track, ValuePen: TGPPen;
begin
  Track := TGPPen.Create(MakeColor(255, GetRValue(ATrack), GetGValue(ATrack),
    GetBValue(ATrack)), APenW);
  ValuePen := nil;
  try
    Track.SetStartCap(LineCapRound);
    Track.SetEndCap(LineCapRound);
    AGraphics.DrawArc(Track, ABox, 135, 270);
    if ALevel > 0.002 then
    begin
      ValuePen := TGPPen.Create(MakeColor(255, GetRValue(AValue),
        GetGValue(AValue), GetBValue(AValue)), APenW);
      ValuePen.SetStartCap(LineCapRound);
      ValuePen.SetEndCap(LineCapRound);
      AGraphics.DrawArc(ValuePen, ABox, 135, Single(270.0 * ALevel));
    end;
  finally
    ValuePen.Free;
    Track.Free;
  end;
end;

procedure DrawDualConcentricMeter(ACanvas: TCanvas; const ARect: TRect;
  AOuterLevel, AInnerLevel: Double; AOuterAccent, AInnerAccent: TColor;
  const APalette: THudPalette; const AMetrics: THudMetrics);
var
  Graphics: TGPGraphics;
  OuterBox, InnerBox: TGPRectF;
  Side, OuterPen, InnerPenW, Gap: Single;
  OuterLv, InnerLv: Double;
  R: TRect;
  RectW, RectH, MinSide: Integer;
begin
  OuterLv := Clamp01(AOuterLevel);
  InnerLv := Clamp01(AInnerLevel);
  RectW := ARect.Right - ARect.Left;
  RectH := ARect.Bottom - ARect.Top;
  Side := RectW;
  if RectH < Side then
    Side := RectH;
  MinSide := AMetrics.MeterPenMin * 6;
  if MinSide < 32 then
    MinSide := 32;
  if Side < MinSide then
    Exit;
  R.Left := ARect.Left + Round((RectW - Side) / 2);
  R.Top := ARect.Top + Round((RectH - Side) / 2);
  R.Right := R.Left + Round(Side);
  R.Bottom := R.Top + Round(Side);
  OuterPen := Side * 0.10;
  if OuterPen < AMetrics.MeterPenMin then
    OuterPen := AMetrics.MeterPenMin;
  InnerPenW := Side * 0.08;
  if InnerPenW < AMetrics.MeterPenMinInner then
    InnerPenW := AMetrics.MeterPenMinInner;
  Gap := OuterPen * 0.35;
  OuterBox.X := R.Left + OuterPen * 0.5;
  OuterBox.Y := R.Top + OuterPen * 0.5;
  OuterBox.Width := Side - OuterPen;
  OuterBox.Height := Side - OuterPen;
  InnerBox.X := OuterBox.X + OuterPen * 0.5 + InnerPenW * 0.5 + Gap;
  InnerBox.Y := OuterBox.Y + OuterPen * 0.5 + InnerPenW * 0.5 + Gap;
  InnerBox.Width := OuterBox.Width - OuterPen - InnerPenW - Gap * 2;
  InnerBox.Height := OuterBox.Height - OuterPen - InnerPenW - Gap * 2;
  if InnerBox.Width < AMetrics.MeterPenMinInner * 3 then
    Exit;

  if not GGdiOk then
  begin
    DrawConcentricMeterFallback(ACanvas, R, OuterLv, AOuterAccent, APalette,
      Round(OuterPen));
    Exit;
  end;

  Graphics := TGPGraphics.Create(ACanvas.Handle);
  try
    Graphics.SetSmoothingMode(SmoothingModeAntiAlias);
    DrawGaugeArc(Graphics, OuterBox, OuterPen, OuterLv, APalette.Grid, AOuterAccent);
    DrawGaugeArc(Graphics, InnerBox, InnerPenW, InnerLv, APalette.Grid, AInnerAccent);
  finally
    Graphics.Free;
  end;
end;

initialization
  InitDashboardGraph;

finalization
  FinalizeDashboardGraph;

end.
