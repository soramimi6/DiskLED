unit uRoutePainter;

{ Ping/route page of the dashboard (PLANNED-3.3.0 item 14).

  Two cards. The upper one shows where the round trip goes: a summary bar
  (the whole RTT split into its segments) and a waterfall with one row per
  hop, each bar running from where the previous hop's persisting delay ends
  to where this hop's begins -- the bar length is the segment delay, and the
  last bar ends at the path's round trip. Delay a router adds only to its own
  replies (not carried to later hops) is drawn as a dashed tail, and the
  hop's min-max spread as a thin line behind the bar.

  The lower card lists the hops with their numbers, scrolled with the mouse
  wheel when they don't fit. }

interface

uses
  Vcl.Graphics,
  System.Types,
  uDashboardTheme,
  uRouteCollector;

type
  TRouteLegendItem = record
    Color: TColor;
    Text: string;
  end;

  TRouteTexts = record
    Title: string;
    { Right side of the title row: target, hop count, round trip, time, or
      the running / failed state. }
    Status: string;
    ColTtl: string;
    ColHost: string;
    ColSeg: string;
    ColRtt: string;
    ColLoss: string;
    ColJitter: string;
    ColDelta: string;
    NoReply: string;
    { Shown instead of the cards' content before any result exists. }
    Empty: string;
    { Legend under the waterfall: the segment colors (address classes, or
      ASes when AS lookup is on), the min-max line and the router's own reply
      delay. }
    LegItems: TArray<TRouteLegendItem>;
    LegRange: string;
    LegExcess: string;
  end;

  TRouteRowView = record
    Hop: TRouteHop;
    { First list line: host name, or the address when it has none. }
    Name: string;
    { Second list line: address, class, reply kind, min / max. }
    Sub: string;
    { Segment color (by address class). }
    Color: TColor;
  end;

  TRouteHit = record
    R: TRect;
    { Index into the rows passed to DrawRoutePage. }
    Index: Integer;
  end;

{ AAnimMs: time since a new result arrived, or -1 to draw it complete. While
  animating, the waterfall bars grow from their left ends one row after
  another (RouteAnimDurationMs covers the whole sequence). }
procedure DrawRoutePage(ACanvas: TCanvas; const ARect: TRect;
  const ATexts: TRouteTexts; const ARows: TArray<TRouteRowView>;
  ATotalMs: Double; AScroll: Integer; AAnimMs: Integer;
  const APalette: THudPalette; const AMetrics: THudMetrics;
  out AHits: TArray<TRouteHit>; out AMaxScroll: Integer);

function RouteAnimDurationMs(ARowCount: Integer): Integer;

{ Segment color of an address class (also the legend's). }
function RouteClassColor(AClass: TRouteAddrClass; const APalette: THudPalette): TColor;
{ Segment color of the AIndex-th distinct AS along the path (cycles). }
function RouteAsColor(AIndex: Integer; const APalette: THudPalette): TColor;

{ "0.8 ms", "12 ms": one decimal below 10 ms. }
function FormatRouteMs(AMs: Double): string;

implementation

uses
  System.SysUtils,
  System.Math,
  Winapi.Windows,
  uDashboardPainter,
  uDashboardGraph;

const
  { Each row starts growing this long after the one above it, and takes
    CAnimGrowMs to reach its full length (ease-out). }
  CAnimStaggerMs = 45;
  CAnimGrowMs = 380;

function RouteAnimDurationMs(ARowCount: Integer): Integer;
begin
  Result := Max(ARowCount - 1, 0) * CAnimStaggerMs + CAnimGrowMs;
end;

{ 0..1 growth of row AIndex at AAnimMs (-1 = done), eased out. }
function RowGrowth(AAnimMs, AIndex: Integer): Double;
var
  F: Double;
begin
  if AAnimMs < 0 then
    Exit(1);
  F := (AAnimMs - AIndex * CAnimStaggerMs) / CAnimGrowMs;
  F := EnsureRange(F, 0, 1);
  Result := 1 - Power(1 - F, 3);
end;

function RouteClassColor(AClass: TRouteAddrClass; const APalette: THudPalette): TColor;
begin
  case AClass of
    acLan: Result := APalette.Mem;
    acCgnat: Result := APalette.Swap;
    acGlobal: Result := APalette.Disk;
  else
    Result := APalette.TextMuted;
  end;
end;

function RouteAsColor(AIndex: Integer; const APalette: THudPalette): TColor;
begin
  { Distinct from the LAN / CGNAT colors, which keep their class meaning. }
  case AIndex mod 5 of
    0: Result := APalette.Disk;
    1: Result := APalette.Net;
    2: Result := APalette.Gpu;
    3: Result := APalette.Cpu;
  else
    Result := APalette.DiskInner;
  end;
end;

function FormatRouteMs(AMs: Double): string;
begin
  if Abs(AMs) < 10 then
    Result := Format('%.1f ms', [AMs])
  else
    Result := Format('%.0f ms', [AMs]);
end;

function SignedMs(AMs: Double): string;
begin
  if AMs > 0.05 then
    Result := '+' + FormatRouteMs(AMs)
  else if AMs < -0.05 then
    Result := #$2212 + FormatRouteMs(-AMs)
  else
    Result := FormatRouteMs(0);
end;

procedure SetFont(ACanvas: TCanvas; ASize: Integer; AStyle: TFontStyles;
  AColor: TColor);
begin
  ACanvas.Brush.Style := bsClear;
  SetBkMode(ACanvas.Handle, TRANSPARENT);
  ACanvas.Font.PixelsPerInch := 96;
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := ASize;
  ACanvas.Font.Style := AStyle;
  ACanvas.Font.Color := AColor;
end;

{ Filled rect that leaves the canvas brush clear for the text after it. }
procedure FillR(ACanvas: TCanvas; const AR: TRect; AColor: TColor);
begin
  if (AR.Right <= AR.Left) or (AR.Bottom <= AR.Top) then
    Exit;
  GpFillRect(ACanvas, AR, AColor);
  ACanvas.Brush.Style := bsClear;
end;

procedure DashedR(ACanvas: TCanvas; const AR: TRect; AColor: TColor;
  ADash, AGap: Integer);
var
  X: Integer;
begin
  X := AR.Left;
  while X < AR.Right do
  begin
    FillR(ACanvas, Rect(X, AR.Top, Min(X + ADash, AR.Right), AR.Bottom), AColor);
    Inc(X, ADash + AGap);
  end;
end;

procedure DrawRoutePage(ACanvas: TCanvas; const ARect: TRect;
  const ATexts: TRouteTexts; const ARows: TArray<TRouteRowView>;
  ATotalMs: Double; AScroll: Integer; AAnimMs: Integer;
  const APalette: THudPalette; const AMetrics: THudMetrics;
  out AHits: TArray<TRouteHit>; out AMaxScroll: Integer);
var
  Top, List: TRect;
  N, i, Y, X0, X1, BarL, BarR, RowH, BarH, TtlW, ValW, TopH, Fixed: Integer;
  Pad, StatusX, HeadH, BodyH, SmallH, ListRowH, ListTop, ListBottom, ContentH: Integer;
  ColRight: array[0..4] of Integer;
  ColW: array[0..4] of Integer;
  Heads: array[0..4] of string;
  Vals: array[0..4] of string;
  AxisMax, Scale, Acc: Double;
  H: TRouteHop;
  Txt: string;
  Saved: Integer;
  c, HostX, HostRight: Integer;
  Grow, SumGrow: Double;
  XEnd: Integer;

  function XAt(AMs: Double): Integer;
  begin
    Result := BarL + Round(AMs * Scale);
    if Result > BarR then
      Result := BarR;
  end;

  procedure AddHit(const AR: TRect; AIndex: Integer);
  begin
    SetLength(AHits, Length(AHits) + 1);
    AHits[High(AHits)].R := AR;
    AHits[High(AHits)].Index := AIndex;
  end;

  { One line under the axis: a sample of each mark and what it means. }
  procedure DrawLegend(AY: Integer);
  var
    LX, Mid, SW, Gap, k: Integer;

    procedure Chip(AColor: TColor; const ALabel: string);
    var
      Txt: string;
    begin
      { Many ASes on a narrow window: drop what no longer fits. }
      if LX + SW + Dip(AMetrics, 24) > Top.Right - Pad then
        Exit;
      FillR(ACanvas, Rect(LX, Mid - Dip(AMetrics, 3), LX + SW, Mid + Dip(AMetrics, 3)), AColor);
      Inc(LX, SW + Dip(AMetrics, 4));
      Txt := Ellipsize(ACanvas, ALabel, Top.Right - Pad - LX);
      ACanvas.TextOut(LX, AY, Txt);
      Inc(LX, ACanvas.TextWidth(Txt) + Gap);
    end;

  begin
    SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
    LX := BarL;
    Mid := AY + SmallH div 2;
    SW := Dip(AMetrics, 14);
    Gap := Dip(AMetrics, 12);
    for k := 0 to High(ATexts.LegItems) do
      Chip(ATexts.LegItems[k].Color, ATexts.LegItems[k].Text);
    FillR(ACanvas, Rect(LX, Mid, LX + SW, Mid + Max(1, Dip(AMetrics, 1))), APalette.TextMuted);
    Inc(LX, SW + Dip(AMetrics, 4));
    ACanvas.TextOut(LX, AY, ATexts.LegRange);
    Inc(LX, ACanvas.TextWidth(ATexts.LegRange) + Gap);
    DashedR(ACanvas, Rect(LX, Mid - Dip(AMetrics, 2), LX + SW, Mid + Dip(AMetrics, 2)),
      APalette.Skip, Dip(AMetrics, 4), Dip(AMetrics, 3));
    Inc(LX, SW + Dip(AMetrics, 4));
    SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
    ACanvas.TextOut(LX, AY, Ellipsize(ACanvas, ATexts.LegExcess, Top.Right - Pad - LX));
  end;

begin
  AHits := nil;
  AMaxScroll := 0;
  N := Length(ARows);
  Pad := AMetrics.CardPad;

  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
  SmallH := ACanvas.TextHeight('Ag');
  SetFont(ACanvas, AMetrics.BodySize, [], APalette.TextPrimary);
  BodyH := ACanvas.TextHeight('Ag');

  { Upper card: title row, summary bar, waterfall rows, axis labels. It takes
    what the hops need, up to about half the page. }
  Fixed := AMetrics.CardHeaderHeight + Dip(AMetrics, 6) + Dip(AMetrics, 12) +
    Dip(AMetrics, 10) + SmallH + Dip(AMetrics, 4) + SmallH + Dip(AMetrics, 6) + Pad;
  RowH := Dip(AMetrics, 16);
  if N > 0 then
  begin
    TopH := (ARect.Height - AMetrics.CardGap) div 2;
    if Fixed + N * RowH > TopH then
      RowH := Max(Dip(AMetrics, 8), (TopH - Fixed) div N);
  end;
  TopH := Fixed + Max(N, 1) * RowH;
  Top := Rect(ARect.Left, ARect.Top, ARect.Right, ARect.Top + TopH);
  List := Rect(ARect.Left, Top.Bottom + AMetrics.CardGap, ARect.Right, ARect.Bottom);

  DrawCardHeader(ACanvas, Top, ATexts.Title, '', APalette.AccentStart, APalette,
    AMetrics);
  { Status on the title row, right-aligned and cut to the room left of it
    (DrawCardHeader draws the title bold, upper-cased, 10 DIP past the bar). }
  SetFont(ACanvas, AMetrics.HeadingSize, [fsBold], APalette.TextMuted);
  StatusX := Top.Left + Pad + Dip(AMetrics, 10) +
    ACanvas.TextWidth(UpperCase(ATexts.Title)) + Dip(AMetrics, 16);
  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
  Txt := Ellipsize(ACanvas, ATexts.Status, Top.Right - Pad - StatusX);
  ACanvas.TextOut(Top.Right - Pad - ACanvas.TextWidth(Txt), Top.Top + Dip(AMetrics, 9),
    Txt);

  FillRoundRect(ACanvas, List, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, List, AMetrics.CardRadius, APalette.CardBorder);

  if N = 0 then
  begin
    SetFont(ACanvas, AMetrics.BodySize, [], APalette.TextMuted);
    ACanvas.TextOut(Top.Left + Pad, Top.Top + AMetrics.CardHeaderHeight + Dip(AMetrics, 6),
      ATexts.Empty);
    Exit;
  end;

  { Time axis: covers the round trip and every bar, tail and whisker. }
  AxisMax := ATotalMs;
  for i := 0 to N - 1 do
    if ARows[i].Hop.Received > 0 then
      AxisMax := Max(AxisMax, Max(ARows[i].Hop.MaxMs, ARows[i].Hop.MedianMs));
  if AxisMax < 1 then
    AxisMax := 1;
  AxisMax := AxisMax * 1.05;

  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
  TtlW := ACanvas.TextWidth('30') + Dip(AMetrics, 10);
  ValW := ACanvas.TextWidth('+000 ms') + Dip(AMetrics, 8);
  BarL := Top.Left + Pad + TtlW;
  BarR := Top.Right - Pad - ValW;
  if BarR <= BarL then
    BarR := BarL + 1;
  Scale := (BarR - BarL) / AxisMax;

  { Summary bar: the round trip split into segments, colored like the rows. }
  Y := Top.Top + AMetrics.CardHeaderHeight + Dip(AMetrics, 6);
  FillR(ACanvas, Rect(BarL, Y, BarR, Y + Dip(AMetrics, 12)), APalette.Grid);
  Acc := 0;
  { While animating, the summary bar is revealed left to right over the whole
    row sequence. }
  if AAnimMs < 0 then
    SumGrow := 1
  else
    SumGrow := EnsureRange(AAnimMs / RouteAnimDurationMs(N), 0, 1);
  XEnd := BarL + Round((XAt(ATotalMs) - BarL) * SumGrow);
  for i := 0 to N - 1 do
  begin
    H := ARows[i].Hop;
    if (H.Received = 0) or (H.SegmentMs <= 0) then
      Continue;
    X0 := XAt(Acc);
    Acc := Acc + H.SegmentMs;
    X1 := Min(XAt(Acc), XEnd);
    if X1 <= X0 then
      Continue;
    if X1 - X0 > 2 then
      Dec(X1); { 1 px seam between segments }
    FillR(ACanvas, Rect(X0, Y, Max(X1, X0 + 1), Y + Dip(AMetrics, 12)), ARows[i].Color);
    AddHit(Rect(X0, Y, Max(X1, X0 + 1), Y + Dip(AMetrics, 12)), i);
  end;
  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextPrimary);
  Txt := FormatRouteMs(ATotalMs);
  ACanvas.TextOut(BarR + Dip(AMetrics, 6), Y + (Dip(AMetrics, 12) - SmallH) div 2, Txt);

  { Waterfall. }
  Y := Y + Dip(AMetrics, 12) + Dip(AMetrics, 10);
  BarH := Max(Dip(AMetrics, 4), RowH * 3 div 5);
  for i := 0 to N - 1 do
  begin
    H := ARows[i].Hop;
    if i > 0 then
      FillR(ACanvas, Rect(Top.Left + Pad, Y, Top.Right - Pad, Y + 1), APalette.Grid);
    SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
    ACanvas.TextOut(Top.Left + Pad, Y + (RowH - SmallH) div 2, IntToStr(H.Ttl));
    AddHit(Rect(Top.Left, Y, Top.Right, Y + RowH), i);
    if H.Received = 0 then
    begin
      ACanvas.TextOut(BarL, Y + (RowH - SmallH) div 2, ATexts.NoReply);
      Inc(Y, RowH);
      Continue;
    end;
    Grow := RowGrowth(AAnimMs, i);
    if Grow <= 0 then
    begin
      Inc(Y, RowH);
      Continue;
    end;
    X0 := XAt(H.EffectiveMs - H.SegmentMs);
    X1 := Max(XAt(H.EffectiveMs), X0 + Max(2, Dip(AMetrics, 2)));
    { The bar grows from its left end; the spread line and the dashed tail
      appear once it has reached full length. }
    if Grow >= 1 then
      FillR(ACanvas, Rect(XAt(H.MinMs), Y + RowH div 2, Max(XAt(H.MaxMs), XAt(H.MinMs) + 1),
        Y + RowH div 2 + Max(1, Dip(AMetrics, 1))), APalette.TextMuted);
    FillR(ACanvas, Rect(X0, Y + (RowH - BarH) div 2, X0 + Round((X1 - X0) * Grow),
      Y + (RowH + BarH) div 2), ARows[i].Color);
    { the router's own reply delay, not carried to later hops }
    if (Grow >= 1) and (H.ExcessMs > 0.5) then
      DashedR(ACanvas, Rect(X1, Y + (RowH - BarH div 2) div 2, XAt(H.MedianMs),
        Y + (RowH + BarH div 2) div 2), APalette.Skip, Dip(AMetrics, 4), Dip(AMetrics, 3));
    SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextPrimary);
    Txt := SignedMs(H.SegmentMs);
    ACanvas.TextOut(Top.Right - Pad - ACanvas.TextWidth(Txt), Y + (RowH - SmallH) div 2, Txt);
    Inc(Y, RowH);
  end;
  { axis labels }
  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
  Y := Y + Dip(AMetrics, 2);
  ACanvas.TextOut(BarL, Y, '0');
  Txt := FormatRouteMs(AxisMax / 2);
  ACanvas.TextOut((BarL + BarR - ACanvas.TextWidth(Txt)) div 2, Y, Txt);
  Txt := FormatRouteMs(AxisMax);
  ACanvas.TextOut(BarR - ACanvas.TextWidth(Txt), Y, Txt);
  DrawLegend(Y + SmallH + Dip(AMetrics, 6));

  { Lower card: list. Numeric columns are as wide as their heading or widest
    value; the host takes the rest. }
  Heads[0] := ATexts.ColSeg;
  Heads[1] := ATexts.ColRtt;
  Heads[2] := ATexts.ColLoss;
  Heads[3] := ATexts.ColJitter;
  Heads[4] := ATexts.ColDelta;
  SetFont(ACanvas, AMetrics.BodySize, [], APalette.TextPrimary);
  for c := 0 to 4 do
    ColW[c] := ACanvas.TextWidth(Heads[c]);
  for c := 0 to 4 do
    ColW[c] := Max(ColW[c], ACanvas.TextWidth('+000 ms'));
  ColRight[4] := List.Right - Pad - Dip(AMetrics, 6);
  for c := 3 downto 0 do
    ColRight[c] := ColRight[c + 1] - ColW[c + 1] - Dip(AMetrics, 12);
  HostX := List.Left + Pad + TtlW;
  HostRight := ColRight[0] - ColW[0] - Dip(AMetrics, 12);

  HeadH := SmallH + Dip(AMetrics, 10);
  SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
  Y := List.Top + Dip(AMetrics, 6);
  ACanvas.TextOut(List.Left + Pad, Y, ATexts.ColTtl);
  ACanvas.TextOut(HostX, Y, ATexts.ColHost);
  for c := 0 to 4 do
    ACanvas.TextOut(ColRight[c] - ACanvas.TextWidth(Heads[c]), Y, Heads[c]);
  ListTop := List.Top + HeadH;
  FillR(ACanvas, Rect(List.Left + Pad, ListTop - 1, List.Right - Pad, ListTop),
    APalette.CardBorder);
  ListBottom := List.Bottom - Dip(AMetrics, 4);

  ListRowH := BodyH + SmallH + Dip(AMetrics, 10);
  ContentH := N * ListRowH;
  AMaxScroll := Max(0, ContentH - (ListBottom - ListTop));
  AScroll := EnsureRange(AScroll, 0, AMaxScroll);

  Saved := SaveDC(ACanvas.Handle);
  try
    IntersectClipRect(ACanvas.Handle, List.Left, ListTop, List.Right, ListBottom);
    for i := 0 to N - 1 do
    begin
      Y := ListTop + i * ListRowH - AScroll;
      if Y + ListRowH < ListTop then
        Continue;
      if Y > ListBottom then
        Break;
      H := ARows[i].Hop;
      AddHit(Rect(List.Left, Max(Y, ListTop), List.Right, Min(Y + ListRowH, ListBottom)), i);
      if i > 0 then
        FillR(ACanvas, Rect(List.Left + Pad, Y, List.Right - Pad, Y + 1), APalette.Grid);
      Y := Y + Dip(AMetrics, 5);
      { segment color chip next to the TTL }
      FillR(ACanvas, Rect(List.Left + Pad - Dip(AMetrics, 6), Y + Dip(AMetrics, 2),
        List.Left + Pad - Dip(AMetrics, 3), Y + BodyH - Dip(AMetrics, 2)), ARows[i].Color);
      SetFont(ACanvas, AMetrics.BodySize, [], APalette.TextPrimary);
      ACanvas.TextOut(List.Left + Pad, Y, IntToStr(H.Ttl));
      ACanvas.TextOut(HostX, Y, Ellipsize(ACanvas, ARows[i].Name, HostRight - HostX));
      if H.Received > 0 then
      begin
        Vals[0] := SignedMs(H.SegmentMs);
        Vals[1] := FormatRouteMs(H.MedianMs);
        Vals[2] := Format('%.0f%%', [H.LossPct]);
        Vals[3] := FormatRouteMs(H.JitterMs);
        if H.HasPrevious then
          Vals[4] := SignedMs(H.DeltaMs)
        else
          Vals[4] := #$2014;
      end
      else
      begin
        Vals[0] := #$2014;
        Vals[1] := #$2014;
        Vals[2] := '100%';
        Vals[3] := #$2014;
        Vals[4] := #$2014;
      end;
      for c := 0 to 4 do
      begin
        { loss above zero is worth noticing }
        if (c = 2) and (H.LossPct > 0) then
          ACanvas.Font.Color := APalette.PingSlow
        else
          ACanvas.Font.Color := APalette.TextPrimary;
        ACanvas.TextOut(ColRight[c] - ACanvas.TextWidth(Vals[c]), Y, Vals[c]);
      end;
      SetFont(ACanvas, AMetrics.HeaderMetaSize, [], APalette.TextMuted);
      ACanvas.TextOut(HostX, Y + BodyH + Dip(AMetrics, 1),
        Ellipsize(ACanvas, ARows[i].Sub, ColRight[4] - HostX));
    end;
  finally
    RestoreDC(ACanvas.Handle, Saved);
  end;

  { scroll position, when the list overflows }
  if AMaxScroll > 0 then
  begin
    BodyH := ListBottom - ListTop;
    X0 := List.Right - Dip(AMetrics, 5);
    Y := ListTop + MulDiv(AScroll, BodyH, ContentH);
    FillR(ACanvas, Rect(X0, Y, X0 + Dip(AMetrics, 3),
      Y + Max(Dip(AMetrics, 12), MulDiv(BodyH, BodyH, ContentH))), APalette.CardBorder);
  end;
end;

end.
