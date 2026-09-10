unit uDashboardCard;

interface

uses
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics,
  uDashboardHistory,
  uDashboardTheme,
  uDashboardGraph;

type
  { 左カラムのセクション: ドーナツグラフ | 履歴グラフ。詳細は右カラムへ。 }
  TDashboardCard = class(TCustomControl)
  private
    FTitle: string;
    FValue: string;
    FValue2: string;
    FSubtitle: string;
    FAccent: TColor;
    FAccent2: TColor;
    FLane: TDashboardLane;
    FLane2: TDashboardLane;
    FMaxY: Double;
    FLevel: Double;
    FLevel2: Double;
    FDual: Boolean;
    FLineStyle: TDashLineStyle;
    FLineStyle2: TDashLineStyle;
    FHistory: TDashboardHistory;
    FAxisNow: string;
    FAxis5m: string;
    FLegend1: string;
    FLegend2: string;
    procedure SetHistory(AValue: TDashboardHistory);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Paint; override;
    procedure InvalidateMeter;
    property Title: string read FTitle write FTitle;
    property Value: string read FValue write FValue;
    property Value2: string read FValue2 write FValue2;
    property Subtitle: string read FSubtitle write FSubtitle;
    property Accent: TColor read FAccent write FAccent;
    property Accent2: TColor read FAccent2 write FAccent2;
    property Lane: TDashboardLane read FLane write FLane;
    property Lane2: TDashboardLane read FLane2 write FLane2;
    property MaxY: Double read FMaxY write FMaxY;
    property Level: Double read FLevel write FLevel;
    property Level2: Double read FLevel2 write FLevel2;
    property Dual: Boolean read FDual write FDual;
    property LineStyle: TDashLineStyle read FLineStyle write FLineStyle;
    property LineStyle2: TDashLineStyle read FLineStyle2 write FLineStyle2;
    property History: TDashboardHistory read FHistory write SetHistory;
    property AxisNow: string read FAxisNow write FAxisNow;
    property Axis5m: string read FAxis5m write FAxis5m;
    property Legend1: string read FLegend1 write FLegend1;
    property Legend2: string read FLegend2 write FLegend2;
    property Color;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  uDashboardPainter,
  uDpiScale,
  uMetricsTypes;

constructor TDashboardCard.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  DoubleBuffered := True;
  TabStop := False;
  FMaxY := 1.0;
  FLevel := 0;
  FLevel2 := 0;
  FDual := False;
  FLineStyle := lsSolid;
  FLineStyle2 := lsSolid;
  Color := HudPalette.Bg;
  Height := 160;
end;

procedure TDashboardCard.SetHistory(AValue: TDashboardHistory);
begin
  FHistory := AValue;
  Invalidate;
end;

procedure TDashboardCard.InvalidateMeter;
var
  R: TRect;
  Met: THudMetrics;
begin
  if not HandleAllocated then
  begin
    Invalidate;
    Exit;
  end;
  Met := HudMetrics(MonitorDpiForWindow(Handle));
  R := Rect(0, 0, Met.MeterPaneWidth, Height);
  InvalidateRect(Handle, @R, False);
end;

procedure TDashboardCard.Paint;
var
  Pal: THudPalette;
  Met: THudMetrics;
  CardR, LeftR, MeterR, GraphR, ClipR: TRect;
  TitleH, LegendW, LegendLineH, MeterTop, Tw, Th, Gap, Sw, Pad, OutlinePx: Integer;
  ValueX, ValueY: Integer;
  DrawGraph: Boolean;
  SavedDc: Integer;
begin
  Pal := HudPalette;
  Met := HudMetrics(MonitorDpiForWindow(Handle));
  Canvas.Font.PixelsPerInch := 96;
  GetClipBox(Canvas.Handle, ClipR);
  DrawGraph := ClipR.Right > Met.MeterPaneWidth;
  SavedDc := 0;
  if not DrawGraph then
  begin
    SavedDc := SaveDC(Canvas.Handle);
    IntersectClipRect(Canvas.Handle, 0, 0, Met.MeterPaneWidth, Height);
  end;
  try
  Canvas.Brush.Color := Pal.Bg;
  Canvas.FillRect(ClientRect);
  CardR := ClientRect;
  FillRoundRect(Canvas, CardR, Met.CardRadius, Pal.Card);
  StrokeRoundRect(Canvas, CardR, Met.CardRadius, Pal.CardBorder);

  LeftR := Rect(Met.CardPad, Met.CardPad, Met.MeterPaneWidth - Met.CardPad,
    Height - Met.CardPad);
  if LeftR.Right < LeftR.Left + MulDiv(48, Met.Margin, 12) then
    LeftR.Right := LeftR.Left + MulDiv(48, Met.Margin, 12);

  TitleH := Met.HeadingSize + MulDiv(8, Met.Margin, 12);
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Size := Met.HeadingSize;
  Canvas.Font.Color := Pal.TextMuted;
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  Canvas.TextOut(LeftR.Left, LeftR.Top, UpperCase(FTitle));

  { Dual-card legend is stacked in the bottom-left of the meter pane; carve a
    column out of the meter rect's left edge so the donut never sits under it.
    The donut is height-constrained here, so a modest carve does not shrink it. }
  Sw := MulDiv(8, Met.Margin, 12);
  if Sw < 4 then
    Sw := 4;
  Pad := MulDiv(2, Met.Margin, 12);
  if Pad < 1 then
    Pad := 1;
  LegendW := 0;
  LegendLineH := 0;
  if FDual and ((FLegend1 <> '') or (FLegend2 <> '')) then
  begin
    Canvas.Font.Style := [];
    Canvas.Font.Size := Met.AxisSize + 1;
    LegendLineH := Canvas.TextHeight('Ag') + MulDiv(3, Met.Margin, 12);
    Tw := Canvas.TextWidth(FLegend1);
    if Canvas.TextWidth(FLegend2) > Tw then
      Tw := Canvas.TextWidth(FLegend2);
    LegendW := Sw + Pad + Tw + MulDiv(8, Met.Margin, 12);
    { Never carve so much (narrow pane + high DPI + long localized label) that
      the meter rect collapses and the donut vanishes. }
    Gap := (LeftR.Right - LeftR.Left) - MulDiv(72, Met.Margin, 12);
    if LegendW > Gap then
      LegendW := Gap;
    if LegendW < 0 then
      LegendW := 0;
  end;

  MeterTop := LeftR.Top + TitleH;
  MeterR := Rect(LeftR.Left + LegendW, MeterTop, LeftR.Right, LeftR.Bottom);
  if MeterR.Bottom < MeterR.Top + MulDiv(24, Met.Margin, 12) then
    MeterR.Bottom := MeterR.Top + MulDiv(24, Met.Margin, 12);

  if FDual then
    DrawDualConcentricMeter(Canvas, MeterR, Clamp01(FLevel), Clamp01(FLevel2),
      FAccent, FAccent2, Pal, Met)
  else
    DrawConcentricMeter(Canvas, MeterR, Clamp01(FLevel), FAccent, Pal, Met);

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.PixelsPerInch := 96;
  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  OutlinePx := MulDiv(2, Met.Margin, 12);
  if OutlinePx < 1 then
    OutlinePx := 1;
  if FDual then
  begin
    Canvas.Font.Size := MulDiv(Met.BodySize + 1, 3, 2);
    Th := Canvas.TextHeight('0');
    Gap := MulDiv(2, Met.Margin, 12);
    if Gap < 1 then
      Gap := 1;
    Tw := Canvas.TextWidth(FValue);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    ValueY := MeterR.Top + ((MeterR.Bottom - MeterR.Top) - (Th * 2 + Gap)) div 2;
    TextOutOutlined(Canvas, ValueX, ValueY, FValue, FAccent, clBlack, OutlinePx);
    Tw := Canvas.TextWidth(FValue2);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    TextOutOutlined(Canvas, ValueX, ValueY + Th + Gap, FValue2, FAccent2, clBlack,
      OutlinePx);
  end
  else
  begin
    Canvas.Font.Size := MulDiv(Met.BigDigitSize, 3, 2);
    Tw := Canvas.TextWidth(FValue);
    if Tw > (MeterR.Right - MeterR.Left) * 3 div 5 then
      Canvas.Font.Size := MulDiv(Met.BodySize, 3, 2);
    Tw := Canvas.TextWidth(FValue);
    Th := Canvas.TextHeight(FValue);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    ValueY := MeterR.Top + ((MeterR.Bottom - MeterR.Top) - Th) div 2;
    TextOutOutlined(Canvas, ValueX, ValueY, FValue, Pal.TextPrimary, clBlack,
      OutlinePx);
  end;

  if LegendW > 0 then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.PixelsPerInch := 96;
    Canvas.Font.Style := [];
    Canvas.Font.Size := Met.AxisSize + 1;
    Canvas.Brush.Style := bsClear;
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Tw := LeftR.Left;
    { Two stacked rows, bottom-aligned to the meter pane. }
    Th := LeftR.Bottom - LegendLineH * 2 + MulDiv(1, Met.Margin, 12);
    Canvas.Brush.Color := FAccent;
    Canvas.Pen.Color := FAccent;
    Canvas.RoundRect(Tw, Th + Pad, Tw + Sw, Th + Pad + Sw, Pad, Pad);
    Canvas.Brush.Style := bsClear;
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Canvas.Font.Color := Pal.TextMuted;
    Canvas.TextOut(Tw + Sw + Pad, Th, FLegend1);
    Th := Th + LegendLineH;
    Canvas.Brush.Color := FAccent2;
    Canvas.Pen.Color := FAccent2;
    Canvas.RoundRect(Tw, Th + Pad, Tw + Sw, Th + Pad + Sw, Pad, Pad);
    Canvas.Brush.Style := bsClear;
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Canvas.Font.Color := Pal.TextMuted;
    Canvas.TextOut(Tw + Sw + Pad, Th, FLegend2);
  end;

  GraphR := Rect(Met.MeterPaneWidth, Met.CardPad + MulDiv(4, Met.Margin, 12),
    Width - Met.CardPad, Height - Met.CardPad - MulDiv(14, Met.Margin, 12));
  if GraphR.Right < GraphR.Left + MulDiv(40, Met.Margin, 12) then
    GraphR.Right := GraphR.Left + MulDiv(40, Met.Margin, 12);
  if GraphR.Bottom < GraphR.Top + MulDiv(24, Met.Margin, 12) then
    GraphR.Bottom := GraphR.Top + MulDiv(24, Met.Margin, 12);
  if DrawGraph then
  begin
    if FDual then
      DrawOverlayMetricGraph(Canvas, GraphR, FHistory, FLane, FAccent, FLineStyle,
        FLane2, FAccent2, FLineStyle2, FMaxY, Pal, Met, FAxisNow, FAxis5m)
    else
      DrawMetricGraph(Canvas, GraphR, FHistory, FLane, FAccent, FMaxY,
        FLineStyle, Pal, Met, FAxisNow, FAxis5m);
  end;
  finally
    if SavedDc <> 0 then
      RestoreDC(Canvas.Handle, SavedDc);
  end;
end;

end.
