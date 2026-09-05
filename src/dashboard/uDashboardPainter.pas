unit uDashboardPainter;

interface

uses
  Vcl.Graphics,
  System.Types,
  uMetricsTypes,
  uDashboardTheme,
  uDashboardHistory,
  uDashboardGraph;

procedure FillRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor);
procedure StrokeRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor);
procedure TextOutOutlined(ACanvas: TCanvas; AX, AY: Integer; const S: string;
  AFill, AOutline: TColor; AOutlinePx: Integer);
procedure DrawCardHeader(ACanvas: TCanvas; const ARect: TRect; const ATitle: string;
  const AValue: string; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawStatPill(ACanvas: TCanvas; const ARect: TRect; const ATitle: string;
  APct: Integer; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawHudHeader(ACanvas: TCanvas; const ARect: TRect; const ATitle,
  ALiveText, AVersion: string; ALiveOn: Boolean; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawCpuPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ANameLbl, ATopoLbl, AClockLbl,
  AUserLbl, AKernelLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawNicList(ACanvas: TCanvas; const ARect: TRect;
  const AAdapters: TArray<TNetAdapterInfo>; const AHeading, AActiveLbl,
  ASkipLbl, ADhcpLbl, AStaticLbl, AGwLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawMemAmounts(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ARamLbl, ASwapLbl,
  ACommitLbl, AUsedLbl, AStandbyLbl, AFreeLbl: string;
  const APalette: THudPalette; const AMetrics: THudMetrics);
procedure DrawDiskQueue(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, AQueueLbl, AReadLbl,
  AWriteLbl, AActiveLbl, ALatencyLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawPowerPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; AAudioL, AAudioR: Double;
  const AHeading, ASourceLbl, AAcLbl, ABattLbl, AUnknownLbl, ARemainLbl,
  AVolHeading, ALeftLbl, ARightLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawPingPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHistory: TArray<TPingHistoryEntry>;
  const AHeading, ATimeLbl, ATargetLbl, ARttLbl, AStatusLbl: string;
  const APalette: THudPalette; const AMetrics: THudMetrics);

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  uAppStrings;

procedure TransparentText(ACanvas: TCanvas);
begin
  ACanvas.Brush.Style := bsClear;
  SetBkMode(ACanvas.Handle, TRANSPARENT);
  ACanvas.Font.PixelsPerInch := 96;
end;

function Dip(const AMetrics: THudMetrics; V: Integer): Integer;
begin
  Result := MulDiv(V, AMetrics.Margin, 12);
  if (V > 0) and (Result < 1) then
    Result := 1;
end;

procedure FillRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor);
var
  R: TRect;
begin
  R := ARect;
  ACanvas.Brush.Color := AColor;
  ACanvas.Pen.Color := AColor;
  ACanvas.RoundRect(R.Left, R.Top, R.Right, R.Bottom, ARadius, ARadius);
end;

procedure StrokeRoundRect(ACanvas: TCanvas; const ARect: TRect; ARadius: Integer;
  AColor: TColor);
begin
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := 1;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom,
    ARadius, ARadius);
  ACanvas.Brush.Style := bsSolid;
end;

procedure TextOutOutlined(ACanvas: TCanvas; AX, AY: Integer; const S: string;
  AFill, AOutline: TColor; AOutlinePx: Integer);
var
  Dx, Dy: Integer;
begin
  if S = '' then
    Exit;
  if AOutlinePx < 1 then
    AOutlinePx := 1;
  TransparentText(ACanvas);
  ACanvas.Font.Color := AOutline;
  for Dy := -AOutlinePx to AOutlinePx do
    for Dx := -AOutlinePx to AOutlinePx do
      if (Dx <> 0) or (Dy <> 0) then
        ACanvas.TextOut(AX + Dx, AY + Dy, S);
  ACanvas.Font.Color := AFill;
  ACanvas.TextOut(AX, AY, S);
end;

procedure DrawCardHeader(ACanvas: TCanvas; const ARect: TRect; const ATitle: string;
  const AValue: string; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Bar: TRect;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  Bar := Rect(ARect.Left + AMetrics.CardPad, ARect.Top + Dip(AMetrics, 6),
    ARect.Left + AMetrics.CardPad + Dip(AMetrics, 3),
    ARect.Top + AMetrics.CardHeaderHeight);
  ACanvas.Brush.Color := AAccent;
  ACanvas.FillRect(Bar);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.CardPad + Dip(AMetrics, 10),
    ARect.Top + Dip(AMetrics, 8), UpperCase(ATitle));
  ACanvas.Font.Style := [];
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Right - ACanvas.TextWidth(AValue) - AMetrics.CardPad,
    ARect.Top + Dip(AMetrics, 6), AValue);
end;

procedure DrawStatPill(ACanvas: TCanvas; const ARect: TRect; const ATitle: string;
  APct: Integer; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Txt: string;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, AAccent);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 10),
    UpperCase(ATitle));
  Txt := Format('%d%%', [APct]);
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BigDigitSize;
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 34), Txt);
end;

procedure DrawHudHeader(ACanvas: TCanvas; const ARect: TRect; const ATitle,
  ALiveText, AVersion: string; ALiveOn: Boolean; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  GradRect: TRect;
  LiveTxt: string;
  BandTop, BandH, TitleY, MetaY, LiveX: Integer;
begin
  ACanvas.Brush.Color := APalette.Bg;
  ACanvas.FillRect(ARect);
  GradRect := Rect(ARect.Left, ARect.Top, ARect.Right,
    ARect.Top + AMetrics.AccentLine);
  ACanvas.Brush.Color := APalette.AccentStart;
  ACanvas.FillRect(GradRect);
  BandTop := ARect.Top + AMetrics.AccentLine;
  BandH := ARect.Bottom - BandTop;

  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeaderTitleSize;
  ACanvas.Font.Color := APalette.TextPrimary;
  TitleY := BandTop + (BandH - ACanvas.TextHeight(ATitle)) div 2;
  ACanvas.TextOut(ARect.Left + Dip(AMetrics, 16), TitleY, ATitle);

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.HeaderMetaSize;
  MetaY := BandTop + (BandH - ACanvas.TextHeight('Ag')) div 2;
  LiveTxt := #$25CF' ' + ALiveText;
  LiveX := ARect.Right - ACanvas.TextWidth(LiveTxt) - Dip(AMetrics, 16);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LiveX - Dip(AMetrics, 12) - ACanvas.TextWidth(AVersion), MetaY, AVersion);
  if ALiveOn then
    ACanvas.Font.Color := APalette.Active
  else
    ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LiveX, MetaY, LiveTxt);
end;

function Ellipsize(ACanvas: TCanvas; const S: string; AMaxW: Integer): string;
var
  T: string;
begin
  Result := S;
  if (AMaxW < 8) or (ACanvas.TextWidth(Result) <= AMaxW) then
    Exit;
  T := Result;
  while (Length(T) > 1) and (ACanvas.TextWidth(T + '...') > AMaxW) do
    SetLength(T, Length(T) - 1);
  Result := T + '...';
end;

function CpuClockText(const ASnap: TMetricsSnapshot): string;
begin
  if (ASnap.CpuCurrentMhz <= 0) and (ASnap.CpuMaxMhz <= 0) then
    Result := #$2014
  else if (ASnap.CpuMaxMhz > 0) and (Abs(ASnap.CpuCurrentMhz - ASnap.CpuMaxMhz) >= 50) then
    Result := Format('%.2f / %.2f GHz',
      [ASnap.CpuCurrentMhz / 1000.0, ASnap.CpuMaxMhz / 1000.0])
  else if ASnap.CpuCurrentMhz > 0 then
    Result := Format('%.2f GHz', [ASnap.CpuCurrentMhz / 1000.0])
  else
    Result := Format('%.2f GHz', [ASnap.CpuMaxMhz / 1000.0]);
end;

procedure DrawCpuPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ANameLbl, ATopoLbl, AClockLbl,
  AUserLbl, AKernelLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Labels: array[0..3] of string;
  Values: array[0..3] of string;
  i, Y, LineH, BlockH, TopY, LabelW, MaxW, InnerTop: Integer;
  NameTxt: string;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));

  if ASnap.CpuName <> '' then
    NameTxt := ASnap.CpuName
  else
    NameTxt := #$2014;
  Labels[0] := ANameLbl;
  Labels[1] := ATopoLbl;
  Labels[2] := AClockLbl;
  Labels[3] := AUserLbl;
  Values[0] := NameTxt;
  Values[1] := Format('%dC / %dT', [ASnap.CpuCores, ASnap.CpuThreads]);
  Values[2] := CpuClockText(ASnap);
  Values[3] := Format('%d%%   %s %d%%',
    [Round(ASnap.CpuUserPct), AKernelLbl, Round(ASnap.CpuKernelPct)]);

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BodySize;
  LineH := ACanvas.TextHeight('Ag') + Dip(AMetrics, 6);
  BlockH := LineH * 4;
  InnerTop := ARect.Top + Dip(AMetrics, 28);
  TopY := InnerTop + ((ARect.Bottom - Dip(AMetrics, 12) - InnerTop) - BlockH) div 2;
  if TopY < InnerTop then
    TopY := InnerTop;
  LabelW := ACanvas.TextWidth(AClockLbl);
  if ACanvas.TextWidth(ANameLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ANameLbl);
  if ACanvas.TextWidth(ATopoLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ATopoLbl);
  if ACanvas.TextWidth(AUserLbl) > LabelW then
    LabelW := ACanvas.TextWidth(AUserLbl);
  Inc(LabelW, Dip(AMetrics, 10));
  MaxW := ARect.Right - ARect.Left - Dip(AMetrics, 24) - LabelW;
  Y := TopY;
  for i := 0 to 3 do
  begin
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, Labels[i]);
    ACanvas.Font.Color := APalette.TextPrimary;
    ACanvas.TextOut(ARect.Left + AMetrics.Margin + LabelW, Y,
      Ellipsize(ACanvas, Values[i], MaxW));
    Inc(Y, LineH);
    if Y + LineH > ARect.Bottom - Dip(AMetrics, 8) then
      Break;
  end;
end;

procedure DrawStackedMemBar(ACanvas: TCanvas; const ARect: TRect;
  AUsed, AStandby, AFree: UInt64; AUsedC, AStandbyC, AFreeC: TColor;
  ARadius: Integer);
var
  Total: UInt64;
  W, X, Wu, Ws, MinSeg: Integer;
begin
  if ARadius < 1 then
    ARadius := 1;
  MinSeg := ARadius div 2;
  if MinSeg < 1 then
    MinSeg := 1;
  ACanvas.Brush.Color := AFreeC;
  ACanvas.Pen.Color := AFreeC;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, ARadius, ARadius);
  Total := AUsed + AStandby + AFree;
  if Total = 0 then
    Exit;
  W := ARect.Right - ARect.Left;
  Wu := Round(W * (AUsed / Total));
  Ws := Round(W * (AStandby / Total));
  if (AUsed > 0) and (Wu < MinSeg) then
    Wu := MinSeg;
  if (AStandby > 0) and (Ws < MinSeg) then
    Ws := MinSeg;
  if Wu + Ws > W then
    Ws := W - Wu;
  X := ARect.Left;
  if Wu > 0 then
  begin
    ACanvas.Brush.Color := AUsedC;
    ACanvas.Pen.Color := AUsedC;
    ACanvas.FillRect(Rect(X, ARect.Top, X + Wu, ARect.Bottom));
    Inc(X, Wu);
  end;
  if Ws > 0 then
  begin
    ACanvas.Brush.Color := AStandbyC;
    ACanvas.Pen.Color := AStandbyC;
    ACanvas.FillRect(Rect(X, ARect.Top, X + Ws, ARect.Bottom));
  end;
end;

procedure DrawUsageBar(ACanvas: TCanvas; const ARect: TRect; ALevel: Double;
  AFill, ATrack: TColor; ARadius: Integer);
var
  FillR: TRect;
  W: Integer;
begin
  if ARadius < 1 then
    ARadius := 1;
  ACanvas.Brush.Color := ATrack;
  ACanvas.Pen.Color := ATrack;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, ARadius, ARadius);
  W := Round((ARect.Right - ARect.Left) * Clamp01(ALevel));
  if W < 1 then
    Exit;
  FillR := Rect(ARect.Left, ARect.Top, ARect.Left + W, ARect.Bottom);
  ACanvas.Brush.Color := AFill;
  ACanvas.Pen.Color := AFill;
  ACanvas.RoundRect(FillR.Left, FillR.Top, FillR.Right, FillR.Bottom, ARadius, ARadius);
end;

procedure DrawNicList(ACanvas: TCanvas; const ARect: TRect;
  const AAdapters: TArray<TNetAdapterInfo>; const AHeading, AActiveLbl,
  ASkipLbl, ADhcpLbl, AStaticLbl, AGwLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  i, Y: Integer;
  Row: TRect;
  Badge, NameTxt, Line2, Gw, Mode: string;
  BadgeColor: TColor;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));
  Y := ARect.Top + Dip(AMetrics, 26);
  for i := 0 to High(AAdapters) do
  begin
    if Y + AMetrics.NicRowHeight > ARect.Bottom - Dip(AMetrics, 6) then
      Break;
    Row := Rect(ARect.Left + Dip(AMetrics, 8), Y, ARect.Right - Dip(AMetrics, 8),
      Y + AMetrics.NicRowHeight);
    if AAdapters[i].Included then
    begin
      Badge := AActiveLbl;
      BadgeColor := APalette.Active;
    end
    else
    begin
      Badge := ASkipLbl;
      BadgeColor := APalette.Skip;
    end;
    if AAdapters[i].FriendlyName <> '' then
      NameTxt := AAdapters[i].FriendlyName
    else
      NameTxt := AAdapters[i].Descr;
    if AAdapters[i].DhcpEnabled then
      Mode := ADhcpLbl
    else
      Mode := AStaticLbl;
    if AAdapters[i].Gateway <> '' then
      Gw := AGwLbl + ' ' + AAdapters[i].Gateway
    else
      Gw := AGwLbl + ' ' + #$2014;
    if AAdapters[i].Ipv4 <> '' then
      Line2 := AAdapters[i].Ipv4 + '  ' + Gw + '  ' + Mode + '  ' +
        FormatLinkSpeedBps(AAdapters[i].LinkSpeedBps)
    else
      Line2 := #$2014 + '  ' + Mode + '  ' + FormatLinkSpeedBps(AAdapters[i].LinkSpeedBps);
    ACanvas.Font.Style := [];
    ACanvas.Font.Size := AMetrics.BodySize;
    TransparentText(ACanvas);
    ACanvas.Font.Color := APalette.TextPrimary;
    ACanvas.TextOut(Row.Left + Dip(AMetrics, 8), Row.Top + Dip(AMetrics, 4), NameTxt);
    ACanvas.Font.Color := BadgeColor;
    ACanvas.TextOut(Row.Right - ACanvas.TextWidth(Badge) - Dip(AMetrics, 12),
      Row.Top + Dip(AMetrics, 4), Badge);
    ACanvas.Font.Size := AMetrics.AxisSize + 1;
    ACanvas.Font.Color := APalette.TextMuted;
    ACanvas.TextOut(Row.Left + Dip(AMetrics, 8), Row.Top + Dip(AMetrics, 22), Line2);
    Inc(Y, AMetrics.NicRowHeight);
  end;
end;

procedure DrawMemAmounts(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ARamLbl, ASwapLbl,
  ACommitLbl, AUsedLbl, AStandbyLbl, AFreeLbl: string;
  const APalette: THudPalette; const AMetrics: THudMetrics);
var
  Bar: TRect;
  Y, Block, InnerTop, ExtraY, MaxW, X, RemainW: Integer;
  Extra, UsedTxt, StandbyTxt, FreeTxt: string;
  Standby, FreeB: UInt64;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));

  InnerTop := ARect.Top + Dip(AMetrics, 28);
  Block := (ARect.Bottom - Dip(AMetrics, 12) - InnerTop) div 2;
  if Block < Dip(AMetrics, 48) then
    Block := Dip(AMetrics, 48);
  MaxW := ARect.Right - ARect.Left - Dip(AMetrics, 24);

  Standby := ASnap.MemCacheBytes;
  if Standby > ASnap.MemAvailBytes then
    Standby := ASnap.MemAvailBytes;
  if ASnap.MemAvailBytes > Standby then
    FreeB := ASnap.MemAvailBytes - Standby
  else
    FreeB := 0;

  Y := InnerTop + Dip(AMetrics, 4);
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.Mem;
  TransparentText(ACanvas);
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, ARamLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + Dip(AMetrics, 56), Y, FormatBytesPair(ASnap.MemUsedBytes, ASnap.MemTotalBytes));
  Bar := Rect(ARect.Left + AMetrics.Margin, Y + Dip(AMetrics, 16),
    ARect.Right - AMetrics.Margin, Y + Dip(AMetrics, 24));
  DrawStackedMemBar(ACanvas, Bar, ASnap.MemUsedBytes, Standby, FreeB,
    APalette.Mem, APalette.MemStandby, APalette.MemFree, Dip(AMetrics, 4));
  ExtraY := Y + Dip(AMetrics, 28);
  if ExtraY + Dip(AMetrics, 14) < InnerTop + Block then
  begin
    UsedTxt := AUsedLbl + ' ' + FormatBytesGiB(ASnap.MemUsedBytes);
    StandbyTxt := AStandbyLbl + ' ' + FormatBytesGiB(Standby);
    FreeTxt := AFreeLbl + ' ' + FormatBytesGiB(FreeB);
    X := ARect.Left + AMetrics.Margin;
    RemainW := MaxW;
    TransparentText(ACanvas);
    ACanvas.Font.Color := APalette.Mem;
    ACanvas.TextOut(X, ExtraY, UsedTxt);
    Inc(X, ACanvas.TextWidth(UsedTxt) + Dip(AMetrics, 12));
    Dec(RemainW, ACanvas.TextWidth(UsedTxt) + Dip(AMetrics, 12));
    if RemainW > Dip(AMetrics, 8) then
    begin
      ACanvas.Font.Color := APalette.MemStandby;
      ACanvas.TextOut(X, ExtraY, StandbyTxt);
      Inc(X, ACanvas.TextWidth(StandbyTxt) + Dip(AMetrics, 12));
      Dec(RemainW, ACanvas.TextWidth(StandbyTxt) + Dip(AMetrics, 12));
    end;
    if RemainW > Dip(AMetrics, 8) then
    begin
      ACanvas.Font.Color := APalette.TextMuted;
      ACanvas.TextOut(X, ExtraY, Ellipsize(ACanvas, FreeTxt, RemainW));
    end;
  end;

  Y := InnerTop + Block + Dip(AMetrics, 4);
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.Swap;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, ASwapLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + Dip(AMetrics, 56), Y, FormatBytesPair(ASnap.SwapUsedBytes, ASnap.SwapTotalBytes));
  Bar := Rect(ARect.Left + AMetrics.Margin, Y + Dip(AMetrics, 16),
    ARect.Right - AMetrics.Margin, Y + Dip(AMetrics, 22));
  DrawUsageBar(ACanvas, Bar, ASnap.SwapUsage / 100.0, APalette.Swap, APalette.Grid,
    Dip(AMetrics, 4));
  ExtraY := Y + Dip(AMetrics, 26);
  if ExtraY + Dip(AMetrics, 14) < ARect.Bottom - Dip(AMetrics, 8) then
  begin
    Extra := ACommitLbl + ' ' + FormatBytesPair(ASnap.MemCommitBytes, ASnap.MemCommitLimitBytes);
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(ARect.Left + AMetrics.Margin, ExtraY, Ellipsize(ACanvas, Extra, MaxW));
  end;
end;

procedure DrawDiskQueue(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, AQueueLbl, AReadLbl,
  AWriteLbl, AActiveLbl, ALatencyLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  QTxt, ActiveTxt, QueueLine: string;
  QY, IopsY, Gap, QW, LineMaxW: Integer;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));

  if ASnap.DiskQueue >= 10 then
    QTxt := Format('%.0f', [ASnap.DiskQueue])
  else
    QTxt := Format('%.1f', [ASnap.DiskQueue]);
  QY := ARect.Top + AMetrics.CardPad * 3;
  IopsY := ARect.Bottom - (AMetrics.PingRowHeight * 3 + AMetrics.CardPad);
  if IopsY < QY + AMetrics.CardPad * 4 then
    IopsY := QY + AMetrics.CardPad * 4;
  Gap := (IopsY - QY - AMetrics.CardPad * 3) div 4;
  if Gap > 0 then
    QY := QY + Gap;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.QueueDigitSize;
  ACanvas.Font.Color := APalette.Disk;
  TransparentText(ACanvas);
  QW := ACanvas.TextWidth(QTxt);
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, QY, QTxt);
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.TextMuted;
  QueueLine := AQueueLbl + '  ・  ' + ALatencyLbl + ' ' + FormatLatencyMs(ASnap.DiskLatencyMs);
  LineMaxW := ARect.Right - (ARect.Left + AMetrics.Margin + QW + AMetrics.CardPad) - AMetrics.Margin;
  if LineMaxW > 0 then
    QueueLine := Ellipsize(ACanvas, QueueLine, LineMaxW);
  ACanvas.TextOut(ARect.Left + AMetrics.Margin + QW + AMetrics.CardPad, QY + AMetrics.BodySize, QueueLine);

  if ASnap.DiskActivePct >= 0 then
    ActiveTxt := Format('%s %.0f%%', [AActiveLbl, ASnap.DiskActivePct])
  else
    ActiveTxt := AActiveLbl + ' ' + #$2014;
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, IopsY, ActiveTxt);
  ACanvas.Font.Color := APalette.Disk;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, IopsY + AMetrics.PingRowHeight,
    AReadLbl + ' ' + FormatIops(ASnap.DiskReadIops));
  ACanvas.Font.Color := APalette.DiskInner;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, IopsY + AMetrics.PingRowHeight * 2,
    AWriteLbl + ' ' + FormatIops(ASnap.DiskWriteIops));
end;

procedure DrawLedMeter(ACanvas: TCanvas; const ARect: TRect; ALevel: Double;
  const APalette: THudPalette);
const
  CMinSlots = 12;
  CMaxSlots = 24;
var
  Count, i, Gap, SegW, X, LitN, Extra, SlotW: Integer;
  R: TRect;
  C: TColor;
  Frac: Double;
begin
  ALevel := Clamp01(ALevel);
  Gap := 1;
  if (ARect.Right - ARect.Left) >= 8 then
    Gap := 2;
  SlotW := ARect.Right - ARect.Left;
  if (SlotW < 1) or (ARect.Bottom <= ARect.Top) then
    Exit;
  Count := SlotW div (Gap + 3);
  if Count > CMaxSlots then
    Count := CMaxSlots;
  if Count < 1 then
    Count := 1;
  if (Count < CMinSlots) and (SlotW >= CMinSlots + Gap * (CMinSlots - 1)) then
    Count := CMinSlots;
  SegW := (SlotW - Gap * (Count - 1)) div Count;
  if SegW < 1 then
    SegW := 1;
  Extra := SlotW - (SegW * Count + Gap * (Count - 1));
  LitN := Round(ALevel * Count);
  X := ARect.Left;
  ACanvas.Pen.Style := psClear;
  for i := 0 to Count - 1 do
  begin
    R := Rect(X, ARect.Top, X + SegW, ARect.Bottom);
    if Extra > 0 then
    begin
      Inc(R.Right);
      Dec(Extra);
    end;
    Frac := (i + 0.5) / Count;
    if i < LitN then
    begin
      if Frac < 0.70 then
        C := APalette.VolGreen
      else if Frac < 0.90 then
        C := APalette.VolYellow
      else
        C := APalette.VolRed;
    end
    else
      C := APalette.VolOff;
    ACanvas.Brush.Color := C;
    ACanvas.FillRect(R);
    X := R.Right + Gap;
  end;
  ACanvas.Pen.Style := psSolid;
end;

procedure DrawPowerPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; AAudioL, AAudioR: Double;
  const AHeading, ASourceLbl, AAcLbl, ABattLbl, AUnknownLbl, ARemainLbl,
  AVolHeading, ALeftLbl, ARightLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Src, BattTxt, RemainTxt, NameTxt, Shown: string;
  Bar: TRect;
  Level: Double;
  Y, LineH, LabelW, H, M, Mid, Gap, BarH, BarY, BarLeft, ChanW, RowGap: Integer;
  NameY, NameH, NameW, MaxNameW, LblY, InnerTop, InnerBot, BlockH: Integer;
  LeftR, RightR: TRect;
begin
  ACanvas.Brush.Color := APalette.Bg;
  ACanvas.Pen.Color := APalette.Bg;
  ACanvas.FillRect(ARect);
  Gap := AMetrics.CardGap;
  Mid := ARect.Left + (ARect.Right - ARect.Left) div 2;
  LeftR := Rect(ARect.Left, ARect.Top, Mid - Gap div 2, ARect.Bottom);
  RightR := Rect(Mid + Gap div 2, ARect.Top, ARect.Right, ARect.Bottom);
  FillRoundRect(ACanvas, LeftR, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, LeftR, AMetrics.CardRadius, APalette.CardBorder);
  FillRoundRect(ACanvas, RightR, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, RightR, AMetrics.CardRadius, APalette.CardBorder);

  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin, LeftR.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));
  ACanvas.TextOut(RightR.Left + AMetrics.Margin, RightR.Top + Dip(AMetrics, 8),
    UpperCase(AVolHeading));

  if ASnap.PowerAc then
    Src := AAcLbl
  else if ASnap.PowerBatteryPresent then
    Src := ABattLbl
  else
    Src := AUnknownLbl;
  if ASnap.PowerBatteryPresent and (ASnap.PowerBatteryPercent >= 0) then
    BattTxt := Format('%d%%', [ASnap.PowerBatteryPercent])
  else
    BattTxt := #$2014;
  if ASnap.PowerRemainSec >= 0 then
  begin
    H := ASnap.PowerRemainSec div 3600;
    M := (ASnap.PowerRemainSec div 60) mod 60;
    RemainTxt := Format('%d:%02d', [H, M]);
  end
  else
    RemainTxt := #$2014;

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BodySize;
  LineH := ACanvas.TextHeight('Ag') + Dip(AMetrics, 18);
  LabelW := ACanvas.TextWidth(ARemainLbl);
  if ACanvas.TextWidth(ASourceLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ASourceLbl);
  if ACanvas.TextWidth(ABattLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ABattLbl);
  Inc(LabelW, Dip(AMetrics, 12));
  Y := LeftR.Top + Dip(AMetrics, 44);
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin, Y, ASourceLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin + LabelW, Y, Src);
  Inc(Y, LineH);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin, Y, ABattLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin + LabelW, Y, BattTxt);
  if ASnap.PowerBatteryPresent and (ASnap.PowerBatteryPercent >= 0) then
    Level := ASnap.PowerBatteryPercent / 100.0
  else
    Level := 0;
  Bar := Rect(LeftR.Left + AMetrics.Margin, Y + LineH - Dip(AMetrics, 4),
    LeftR.Right - AMetrics.Margin, Y + LineH + Dip(AMetrics, 4));
  if Bar.Right > Bar.Left then
    DrawUsageBar(ACanvas, Bar, Level, APalette.Active, APalette.Grid, Dip(AMetrics, 4));
  Inc(Y, LineH + Dip(AMetrics, 14));
  ACanvas.Font.Color := APalette.TextMuted;
  TransparentText(ACanvas);
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin, Y, ARemainLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(LeftR.Left + AMetrics.Margin + LabelW, Y, RemainTxt);

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BodySize;
  TransparentText(ACanvas);
  if ASnap.AudioDeviceName <> '' then
    NameTxt := ASnap.AudioDeviceName
  else
    NameTxt := #$2014;
  NameH := ACanvas.TextHeight('Ag');
  NameY := RightR.Bottom - AMetrics.Margin - NameH;
  MaxNameW := (RightR.Right - RightR.Left) - AMetrics.Margin * 2;
  if MaxNameW < 8 then
    MaxNameW := 8;
  ChanW := ACanvas.TextWidth(ALeftLbl);
  if ACanvas.TextWidth(ARightLbl) > ChanW then
    ChanW := ACanvas.TextWidth(ARightLbl);
  Inc(ChanW, Dip(AMetrics, 8));
  BarH := Dip(AMetrics, 16);
  RowGap := Dip(AMetrics, 12);
  InnerTop := RightR.Top + Dip(AMetrics, 36);
  InnerBot := NameY - Dip(AMetrics, 8);
  BlockH := BarH * 2 + RowGap;
  BarY := InnerTop + ((InnerBot - InnerTop) - BlockH) div 2;
  if BarY < InnerTop then
    BarY := InnerTop;
  BarLeft := RightR.Left + AMetrics.Margin + ChanW;
  if BarLeft + Dip(AMetrics, 16) < RightR.Right - AMetrics.Margin then
  begin
    LblY := BarY + (BarH - NameH) div 2;
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(RightR.Left + AMetrics.Margin, LblY, ALeftLbl);
    Bar := Rect(BarLeft, BarY, RightR.Right - AMetrics.Margin, BarY + BarH);
    if Bar.Right > Bar.Left then
      DrawLedMeter(ACanvas, Bar, AAudioL, APalette);
    Inc(BarY, BarH + RowGap);
    LblY := BarY + (BarH - NameH) div 2;
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(RightR.Left + AMetrics.Margin, LblY, ARightLbl);
    Bar := Rect(BarLeft, BarY, RightR.Right - AMetrics.Margin, BarY + BarH);
    if Bar.Right > Bar.Left then
      DrawLedMeter(ACanvas, Bar, AAudioR, APalette);
  end;
  Shown := Ellipsize(ACanvas, NameTxt, MaxNameW);
  NameW := ACanvas.TextWidth(Shown);
  ACanvas.Font.Color := APalette.TextPrimary;
  TransparentText(ACanvas);
  ACanvas.TextOut(RightR.Left + ((RightR.Right - RightR.Left) - NameW) div 2,
    NameY, Shown);
end;

function PingStatusText(const AEntry: TPingHistoryEntry): string;
begin
  if not AEntry.Ok then
    Exit('TIMEOUT');
  Result := Format('%.0f ms', [AEntry.RttMs]);
end;

function PingLevelLabel(ALevel: TPingLevel): string;
begin
  case ALevel of
    plNormal: Result := 'OK';
    plFair: Result := 'FAIR';
    plSlow: Result := 'SLOW';
  else
    Result := 'TIMEOUT';
  end;
end;

procedure DrawPingPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHistory: TArray<TPingHistoryEntry>;
  const AHeading, ATimeLbl, ATargetLbl, ARttLbl, AStatusLbl: string;
  const APalette: THudPalette; const AMetrics: THudMetrics);
const
  CHistRows = 5;
var
  Y, i, Shown, First, RttW, HostX, HostMaxW: Integer;
  RttTxt, HostTxt, TimeTxt, StatusTxt: string;
  RowH: Integer;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, ARect.Top + Dip(AMetrics, 8),
    UpperCase(AHeading));

  Y := ARect.Top + Dip(AMetrics, 24);
  if ASnap.PingOk then
    RttTxt := Format('%.0f ms', [ASnap.PingRttMs])
  else if ASnap.PingPending then
    RttTxt := S('hover.ping_pending')
  else
    RttTxt := S('hover.ping_timeout');
  HostTxt := ASnap.PingTarget;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.PingHeroSize;
  TransparentText(ACanvas);
  ACanvas.Font.Color := PingLevelColor(APalette, Ord(ASnap.PingLevel));
  RttW := ACanvas.TextWidth(RttTxt);
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, RttTxt);
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.TextPrimary;
  HostX := ARect.Left + AMetrics.Margin + RttW + Dip(AMetrics, 20);
  HostMaxW := ARect.Right - AMetrics.Margin - HostX;
  if HostMaxW < Dip(AMetrics, 24) then
    HostMaxW := Dip(AMetrics, 24);
  ACanvas.TextOut(HostX, Y + Dip(AMetrics, 2), Ellipsize(ACanvas, HostTxt, HostMaxW));

  RowH := AMetrics.PingRowHeight;
  Inc(Y, Dip(AMetrics, 22));
  ACanvas.Font.Name := 'Consolas';
  ACanvas.Font.Size := AMetrics.MonoSize;
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, ATimeLbl);
  ACanvas.TextOut(ARect.Left + Dip(AMetrics, 78), Y, ATargetLbl);
  ACanvas.TextOut(ARect.Left + Dip(AMetrics, 188), Y, ARttLbl);
  ACanvas.TextOut(ARect.Right - Dip(AMetrics, 64), Y, AStatusLbl);
  Inc(Y, RowH);

  Shown := Length(AHistory);
  if Shown > CHistRows then
    Shown := CHistRows;
  if Shown > 0 then
  begin
    First := Length(AHistory) - Shown;
    for i := Length(AHistory) - 1 downto First do
    begin
      if Y + RowH > ARect.Bottom - Dip(AMetrics, 6) then
        Break;
    TimeTxt := FormatDateTime('hh:nn:ss', AHistory[i].When);
    if AHistory[i].Target <> '' then
      HostTxt := AHistory[i].Target
    else
      HostTxt := #$2014;
    StatusTxt := PingLevelLabel(AHistory[i].Level);
    TransparentText(ACanvas);
    ACanvas.Font.Color := APalette.TextPrimary;
    ACanvas.TextOut(ARect.Left + AMetrics.Margin, Y, TimeTxt);
    ACanvas.TextOut(ARect.Left + Dip(AMetrics, 78), Y,
      Ellipsize(ACanvas, HostTxt, Dip(AMetrics, 100)));
    ACanvas.Font.Color := PingLevelColor(APalette, Ord(AHistory[i].Level));
    ACanvas.TextOut(ARect.Left + Dip(AMetrics, 188), Y, PingStatusText(AHistory[i]));
    ACanvas.TextOut(ARect.Right - Dip(AMetrics, 64), Y, StatusTxt);
      Inc(Y, RowH);
    end;
  end;
end;

end.
