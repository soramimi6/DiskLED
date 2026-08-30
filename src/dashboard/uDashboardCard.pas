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

procedure TDashboardCard.Paint;
var
  Pal: THudPalette;
  Met: THudMetrics;
  CardR, LeftR, MeterR, GraphR: TRect;
  TitleH, MeterTop, Tw, Th, Gap: Integer;
  ValueX, ValueY: Integer;
begin
  Pal := HudPalette;
  Met := HudMetrics;
  Canvas.Brush.Color := Pal.Bg;
  Canvas.FillRect(ClientRect);
  CardR := ClientRect;
  FillRoundRect(Canvas, CardR, Met.CardRadius, Pal.Card);
  StrokeRoundRect(Canvas, CardR, Met.CardRadius, Pal.CardBorder);

  LeftR := Rect(Met.CardPad, Met.CardPad, Met.MeterPaneWidth - Met.CardPad,
    Height - Met.CardPad);
  if LeftR.Right < LeftR.Left + 48 then
    LeftR.Right := LeftR.Left + 48;

  TitleH := Met.HeadingSize + 8;
  if FDual and ((FLegend1 <> '') or (FLegend2 <> '')) then
    TitleH := TitleH + Met.BodySize + 4;
  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [fsBold];
  Canvas.Font.Size := Met.HeadingSize;
  Canvas.Font.Color := Pal.TextMuted;
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  Canvas.TextOut(LeftR.Left, LeftR.Top, UpperCase(FTitle));
  if FDual and ((FLegend1 <> '') or (FLegend2 <> '')) then
  begin
    Canvas.Font.Style := [];
    Canvas.Font.Size := Met.AxisSize + 1;
    Tw := LeftR.Left;
    Th := LeftR.Top + Met.HeadingSize + 6;
    Canvas.Brush.Color := FAccent;
    Canvas.Pen.Color := FAccent;
    Canvas.RoundRect(Tw, Th + 2, Tw + 8, Th + 10, 2, 2);
    Canvas.Brush.Style := bsClear;
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Canvas.Font.Color := Pal.TextMuted;
    Canvas.TextOut(Tw + 10, Th, FLegend1);
    Tw := Tw + 10 + Canvas.TextWidth(FLegend1) + 10;
    Canvas.Brush.Color := FAccent2;
    Canvas.Pen.Color := FAccent2;
    Canvas.RoundRect(Tw, Th + 2, Tw + 8, Th + 10, 2, 2);
    Canvas.Brush.Style := bsClear;
    SetBkMode(Canvas.Handle, TRANSPARENT);
    Canvas.Font.Color := Pal.TextMuted;
    Canvas.TextOut(Tw + 10, Th, FLegend2);
  end;

  MeterTop := LeftR.Top + TitleH;
  MeterR := Rect(LeftR.Left, MeterTop, LeftR.Right, LeftR.Bottom);
  if MeterR.Bottom < MeterR.Top + 24 then
    MeterR.Bottom := MeterR.Top + 24;

  if FDual then
    DrawDualConcentricMeter(Canvas, MeterR, Clamp01(FLevel), Clamp01(FLevel2),
      FAccent, FAccent2, Pal)
  else
    DrawConcentricMeter(Canvas, MeterR, Clamp01(FLevel), FAccent, Pal);

  Canvas.Font.Name := 'Segoe UI';
  Canvas.Font.Style := [];
  Canvas.Brush.Style := bsClear;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  if FDual then
  begin
    Canvas.Font.Size := Met.BodySize + 1;
    Th := Canvas.TextHeight('0');
    Gap := 2;
    Canvas.Font.Color := FAccent;
    Tw := Canvas.TextWidth(FValue);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    ValueY := MeterR.Top + ((MeterR.Bottom - MeterR.Top) - (Th * 2 + Gap)) div 2;
    Canvas.TextOut(ValueX, ValueY, FValue);
    Canvas.Font.Color := FAccent2;
    Tw := Canvas.TextWidth(FValue2);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    Canvas.TextOut(ValueX, ValueY + Th + Gap, FValue2);
  end
  else
  begin
    Canvas.Font.Size := Met.BigDigitSize;
    Canvas.Font.Color := Pal.TextPrimary;
    Tw := Canvas.TextWidth(FValue);
    if Tw > (MeterR.Right - MeterR.Left) * 3 div 5 then
      Canvas.Font.Size := Met.BodySize;
    Tw := Canvas.TextWidth(FValue);
    Th := Canvas.TextHeight(FValue);
    ValueX := MeterR.Left + ((MeterR.Right - MeterR.Left) - Tw) div 2;
    ValueY := MeterR.Top + ((MeterR.Bottom - MeterR.Top) - Th) div 2;
    Canvas.TextOut(ValueX, ValueY, FValue);
  end;

  GraphR := Rect(Met.MeterPaneWidth, Met.CardPad + 4,
    Width - Met.CardPad, Height - Met.CardPad - 14);
  if GraphR.Right < GraphR.Left + 40 then
    GraphR.Right := GraphR.Left + 40;
  if GraphR.Bottom < GraphR.Top + 24 then
    GraphR.Bottom := GraphR.Top + 24;
  if FDual then
    DrawOverlayMetricGraph(Canvas, GraphR, FHistory, FLane, FAccent, FLineStyle,
      FLane2, FAccent2, FLineStyle2, FMaxY, Pal, Met, FAxisNow, FAxis5m)
  else
    DrawMetricGraph(Canvas, GraphR, FHistory, FLane, FAccent, FMaxY,
      FLineStyle, Pal, Met, FAxisNow, FAxis5m);
end;

end.
