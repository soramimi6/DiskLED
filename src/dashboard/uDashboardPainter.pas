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
  AWriteLbl, AActiveLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
procedure DrawPowerPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ASourceLbl, AAcLbl, ABattLbl,
  AUnknownLbl, ARemainLbl: string; const APalette: THudPalette;
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

procedure DrawCardHeader(ACanvas: TCanvas; const ARect: TRect; const ATitle: string;
  const AValue: string; AAccent: TColor; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Bar: TRect;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  Bar := Rect(ARect.Left + AMetrics.CardPad, ARect.Top + 6,
    ARect.Left + AMetrics.CardPad + 3, ARect.Top + AMetrics.CardHeaderHeight);
  ACanvas.Brush.Color := AAccent;
  ACanvas.FillRect(Bar);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + AMetrics.CardPad + 10, ARect.Top + 8, UpperCase(ATitle));
  ACanvas.Font.Style := [];
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Right - ACanvas.TextWidth(AValue) - AMetrics.CardPad,
    ARect.Top + 6, AValue);
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
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 10, UpperCase(ATitle));
  Txt := Format('%d%%', [APct]);
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BigDigitSize;
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 34, Txt);
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
  ACanvas.Font.Size := 12;
  ACanvas.Font.Color := APalette.TextPrimary;
  TitleY := BandTop + (BandH - ACanvas.TextHeight(ATitle)) div 2;
  ACanvas.TextOut(ARect.Left + 16, TitleY, ATitle);

  ACanvas.Font.Style := [];
  ACanvas.Font.Size := 9;
  MetaY := BandTop + (BandH - ACanvas.TextHeight('Ag')) div 2;
  LiveTxt := #$25CF' ' + ALiveText;
  LiveX := ARect.Right - ACanvas.TextWidth(LiveTxt) - 16;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(LiveX - 12 - ACanvas.TextWidth(AVersion), MetaY, AVersion);
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
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));

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
  LineH := ACanvas.TextHeight('Ag') + 6;
  BlockH := LineH * 4;
  InnerTop := ARect.Top + 28;
  TopY := InnerTop + ((ARect.Bottom - 12 - InnerTop) - BlockH) div 2;
  if TopY < InnerTop then
    TopY := InnerTop;
  LabelW := ACanvas.TextWidth(AClockLbl);
  if ACanvas.TextWidth(ANameLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ANameLbl);
  if ACanvas.TextWidth(ATopoLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ATopoLbl);
  if ACanvas.TextWidth(AUserLbl) > LabelW then
    LabelW := ACanvas.TextWidth(AUserLbl);
  Inc(LabelW, 10);
  MaxW := ARect.Right - ARect.Left - 24 - LabelW;
  Y := TopY;
  for i := 0 to 3 do
  begin
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(ARect.Left + 12, Y, Labels[i]);
    ACanvas.Font.Color := APalette.TextPrimary;
    ACanvas.TextOut(ARect.Left + 12 + LabelW, Y,
      Ellipsize(ACanvas, Values[i], MaxW));
    Inc(Y, LineH);
    if Y + LineH > ARect.Bottom - 8 then
      Break;
  end;
end;

procedure DrawStackedMemBar(ACanvas: TCanvas; const ARect: TRect;
  AUsed, AStandby, AFree: UInt64; AUsedC, AStandbyC, AFreeC: TColor);
var
  Total: UInt64;
  W, X, Wu, Ws: Integer;
begin
  ACanvas.Brush.Color := AFreeC;
  ACanvas.Pen.Color := AFreeC;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 4, 4);
  Total := AUsed + AStandby + AFree;
  if Total = 0 then
    Exit;
  W := ARect.Right - ARect.Left;
  Wu := Round(W * (AUsed / Total));
  Ws := Round(W * (AStandby / Total));
  if (AUsed > 0) and (Wu < 2) then
    Wu := 2;
  if (AStandby > 0) and (Ws < 2) then
    Ws := 2;
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
  AFill, ATrack: TColor);
var
  FillR: TRect;
  W: Integer;
begin
  ACanvas.Brush.Color := ATrack;
  ACanvas.Pen.Color := ATrack;
  ACanvas.RoundRect(ARect.Left, ARect.Top, ARect.Right, ARect.Bottom, 4, 4);
  W := Round((ARect.Right - ARect.Left) * Clamp01(ALevel));
  if W < 2 then
    Exit;
  FillR := Rect(ARect.Left, ARect.Top, ARect.Left + W, ARect.Bottom);
  ACanvas.Brush.Color := AFill;
  ACanvas.Pen.Color := AFill;
  ACanvas.RoundRect(FillR.Left, FillR.Top, FillR.Right, FillR.Bottom, 4, 4);
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
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));
  Y := ARect.Top + 26;
  for i := 0 to High(AAdapters) do
  begin
    if Y + AMetrics.NicRowHeight > ARect.Bottom - 6 then
      Break;
    Row := Rect(ARect.Left + 8, Y, ARect.Right - 8, Y + AMetrics.NicRowHeight);
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
    ACanvas.TextOut(Row.Left + 8, Row.Top + 4, NameTxt);
    ACanvas.Font.Color := BadgeColor;
    ACanvas.TextOut(Row.Right - ACanvas.TextWidth(Badge) - 12, Row.Top + 4, Badge);
    ACanvas.Font.Size := AMetrics.AxisSize + 1;
    ACanvas.Font.Color := APalette.TextMuted;
    ACanvas.TextOut(Row.Left + 8, Row.Top + 22, Line2);
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
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));

  InnerTop := ARect.Top + 28;
  Block := (ARect.Bottom - 12 - InnerTop) div 2;
  if Block < 48 then
    Block := 48;
  MaxW := ARect.Right - ARect.Left - 24;

  Standby := ASnap.MemCacheBytes;
  if Standby > ASnap.MemAvailBytes then
    Standby := ASnap.MemAvailBytes;
  if ASnap.MemAvailBytes > Standby then
    FreeB := ASnap.MemAvailBytes - Standby
  else
    FreeB := 0;

  Y := InnerTop + 4;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.Mem;
  TransparentText(ACanvas);
  ACanvas.TextOut(ARect.Left + 12, Y, ARamLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 56, Y, FormatBytesPair(ASnap.MemUsedBytes, ASnap.MemTotalBytes));
  Bar := Rect(ARect.Left + 12, Y + 16, ARect.Right - 12, Y + 24);
  DrawStackedMemBar(ACanvas, Bar, ASnap.MemUsedBytes, Standby, FreeB,
    APalette.Mem, APalette.MemStandby, APalette.MemFree);
  ExtraY := Y + 28;
  if ExtraY + 14 < InnerTop + Block then
  begin
    UsedTxt := AUsedLbl + ' ' + FormatBytesGiB(ASnap.MemUsedBytes);
    StandbyTxt := AStandbyLbl + ' ' + FormatBytesGiB(Standby);
    FreeTxt := AFreeLbl + ' ' + FormatBytesGiB(FreeB);
    X := ARect.Left + 12;
    RemainW := MaxW;
    TransparentText(ACanvas);
    ACanvas.Font.Color := APalette.Mem;
    ACanvas.TextOut(X, ExtraY, UsedTxt);
    Inc(X, ACanvas.TextWidth(UsedTxt) + 12);
    Dec(RemainW, ACanvas.TextWidth(UsedTxt) + 12);
    if RemainW > 8 then
    begin
      ACanvas.Font.Color := APalette.MemStandby;
      ACanvas.TextOut(X, ExtraY, StandbyTxt);
      Inc(X, ACanvas.TextWidth(StandbyTxt) + 12);
      Dec(RemainW, ACanvas.TextWidth(StandbyTxt) + 12);
    end;
    if RemainW > 8 then
    begin
      ACanvas.Font.Color := APalette.TextMuted;
      ACanvas.TextOut(X, ExtraY, Ellipsize(ACanvas, FreeTxt, RemainW));
    end;
  end;

  Y := InnerTop + Block + 4;
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.Swap;
  ACanvas.TextOut(ARect.Left + 12, Y, ASwapLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 56, Y, FormatBytesPair(ASnap.SwapUsedBytes, ASnap.SwapTotalBytes));
  Bar := Rect(ARect.Left + 12, Y + 16, ARect.Right - 12, Y + 22);
  DrawUsageBar(ACanvas, Bar, ASnap.SwapUsage / 100.0, APalette.Swap, APalette.Grid);
  ExtraY := Y + 26;
  if ExtraY + 14 < ARect.Bottom - 8 then
  begin
    Extra := ACommitLbl + ' ' + FormatBytesPair(ASnap.MemCommitBytes, ASnap.MemCommitLimitBytes);
    ACanvas.Font.Color := APalette.TextMuted;
    TransparentText(ACanvas);
    ACanvas.TextOut(ARect.Left + 12, ExtraY, Ellipsize(ACanvas, Extra, MaxW));
  end;
end;

procedure DrawDiskQueue(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, AQueueLbl, AReadLbl,
  AWriteLbl, AActiveLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  QTxt, ActiveTxt: string;
  QY, IopsY, Gap, QW: Integer;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));

  if ASnap.DiskQueue >= 10 then
    QTxt := Format('%.0f', [ASnap.DiskQueue])
  else
    QTxt := Format('%.1f', [ASnap.DiskQueue]);
  QY := ARect.Top + 32;
  IopsY := ARect.Bottom - 64;
  if IopsY < QY + 44 then
    IopsY := QY + 44;
  Gap := (IopsY - QY - 36) div 4;
  if Gap > 0 then
    QY := QY + Gap;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := 28;
  ACanvas.Font.Color := APalette.Disk;
  TransparentText(ACanvas);
  QW := ACanvas.TextWidth(QTxt);
  ACanvas.TextOut(ARect.Left + 12, QY, QTxt);
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12 + QW + 10, QY + 14, AQueueLbl);

  if ASnap.DiskActivePct >= 0 then
    ActiveTxt := Format('%s %.0f%%', [AActiveLbl, ASnap.DiskActivePct])
  else
    ActiveTxt := AActiveLbl + ' ' + #$2014;
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 12, IopsY, ActiveTxt);
  ACanvas.Font.Color := APalette.Disk;
  ACanvas.TextOut(ARect.Left + 12, IopsY + 16,
    AReadLbl + ' ' + FormatIops(ASnap.DiskReadIops));
  ACanvas.Font.Color := APalette.DiskInner;
  ACanvas.TextOut(ARect.Left + 12, IopsY + 32,
    AWriteLbl + ' ' + FormatIops(ASnap.DiskWriteIops));
end;

procedure DrawPowerPanel(ACanvas: TCanvas; const ARect: TRect;
  const ASnap: TMetricsSnapshot; const AHeading, ASourceLbl, AAcLbl, ABattLbl,
  AUnknownLbl, ARemainLbl: string; const APalette: THudPalette;
  const AMetrics: THudMetrics);
var
  Src, BattTxt, RemainTxt: string;
  Bar: TRect;
  Level: Double;
  Y, LineH, LabelW, H, M: Integer;
begin
  FillRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.Card);
  StrokeRoundRect(ACanvas, ARect, AMetrics.CardRadius, APalette.CardBorder);
  TransparentText(ACanvas);
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Size := AMetrics.HeadingSize;
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));

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
  LineH := ACanvas.TextHeight('Ag') + 18;
  LabelW := ACanvas.TextWidth(ARemainLbl);
  if ACanvas.TextWidth(ASourceLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ASourceLbl);
  if ACanvas.TextWidth(ABattLbl) > LabelW then
    LabelW := ACanvas.TextWidth(ABattLbl);
  Inc(LabelW, 12);
  Y := ARect.Top + 44;
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12, Y, ASourceLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 12 + LabelW, Y, Src);
  Inc(Y, LineH);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12, Y, ABattLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 12 + LabelW, Y, BattTxt);
  if ASnap.PowerBatteryPresent and (ASnap.PowerBatteryPercent >= 0) then
    Level := ASnap.PowerBatteryPercent / 100.0
  else
    Level := 0;
  Bar := Rect(ARect.Left + 12, Y + LineH - 4, ARect.Right - 12, Y + LineH + 4);
  DrawUsageBar(ACanvas, Bar, Level, APalette.Active, APalette.Grid);
  Inc(Y, LineH + 14);
  ACanvas.Font.Color := APalette.TextMuted;
  TransparentText(ACanvas);
  ACanvas.TextOut(ARect.Left + 12, Y, ARemainLbl);
  ACanvas.Font.Color := APalette.TextPrimary;
  ACanvas.TextOut(ARect.Left + 12 + LabelW, Y, RemainTxt);
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
  ACanvas.TextOut(ARect.Left + 12, ARect.Top + 8, UpperCase(AHeading));

  Y := ARect.Top + 24;
  if ASnap.PingOk then
    RttTxt := Format('%.0f ms', [ASnap.PingRttMs])
  else if ASnap.PingPending then
    RttTxt := S('hover.ping_pending')
  else
    RttTxt := S('hover.ping_timeout');
  HostTxt := ASnap.PingTarget;
  ACanvas.Font.Style := [];
  ACanvas.Font.Size := 14;
  TransparentText(ACanvas);
  ACanvas.Font.Color := PingLevelColor(APalette, Ord(ASnap.PingLevel));
  RttW := ACanvas.TextWidth(RttTxt);
  ACanvas.TextOut(ARect.Left + 12, Y, RttTxt);
  ACanvas.Font.Size := AMetrics.BodySize;
  ACanvas.Font.Color := APalette.TextPrimary;
  HostX := ARect.Left + 12 + RttW + 20;
  HostMaxW := ARect.Right - 12 - HostX;
  if HostMaxW < 24 then
    HostMaxW := 24;
  ACanvas.TextOut(HostX, Y + 2, Ellipsize(ACanvas, HostTxt, HostMaxW));

  RowH := AMetrics.PingRowHeight;
  Inc(Y, 22);
  ACanvas.Font.Name := 'Consolas';
  ACanvas.Font.Size := AMetrics.MonoSize;
  TransparentText(ACanvas);
  ACanvas.Font.Color := APalette.TextMuted;
  ACanvas.TextOut(ARect.Left + 12, Y, ATimeLbl);
  ACanvas.TextOut(ARect.Left + 78, Y, ATargetLbl);
  ACanvas.TextOut(ARect.Left + 188, Y, ARttLbl);
  ACanvas.TextOut(ARect.Right - 64, Y, AStatusLbl);
  Inc(Y, RowH);

  Shown := Length(AHistory);
  if Shown > CHistRows then
    Shown := CHistRows;
  if Shown > 0 then
  begin
    First := Length(AHistory) - Shown;
    for i := Length(AHistory) - 1 downto First do
    begin
      if Y + RowH > ARect.Bottom - 6 then
        Break;
    TimeTxt := FormatDateTime('hh:nn:ss', AHistory[i].When);
    if AHistory[i].Target <> '' then
      HostTxt := AHistory[i].Target
    else
      HostTxt := #$2014;
    StatusTxt := PingLevelLabel(AHistory[i].Level);
    TransparentText(ACanvas);
    ACanvas.Font.Color := APalette.TextPrimary;
    ACanvas.TextOut(ARect.Left + 12, Y, TimeTxt);
    ACanvas.TextOut(ARect.Left + 78, Y,
      Ellipsize(ACanvas, HostTxt, 100));
    ACanvas.Font.Color := PingLevelColor(APalette, Ord(AHistory[i].Level));
    ACanvas.TextOut(ARect.Left + 188, Y, PingStatusText(AHistory[i]));
    ACanvas.TextOut(ARect.Right - 64, Y, StatusTxt);
      Inc(Y, RowH);
    end;
  end;
end;

end.
