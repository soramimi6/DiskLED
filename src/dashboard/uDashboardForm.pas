unit uDashboardForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  uCollector,
  uDisplayPipeline,
  uDashboardHistory,
  uDashboardTheme,
  uDashboardPainter,
  uDashboardCard,
  uDashboardGraph,
  uSettings,
  uMetricsTypes,
  uDpiScale;

{ Dashboard regions (docs/DESIGN.md, .cursor/rules/dashboard-regions.mdc):
  ヘッダー
  左カラム — セクション × 5 (ドーナツグラフ | 履歴グラフ)
  右カラム — サブセクション × 5 (CPU / メモリ / 電源（左：電源 | 右：音量） / ディスクキュー / Ping)
  Do not put subsection facts inside a left-column section. }
type
  TDashboardForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormHide(Sender: TObject);
  private
    FPipeline: TDisplayPipeline;
    FHistory: TDashboardHistory;
    FCollector: TMetricsCollector;
    FSettings: TAppSettings;
    FHeaderPaint: TPaintBox;
    FCpuPaint: TPaintBox;
    FMemPaint: TPaintBox;
    FQueuePaint: TPaintBox;
    FPowerPaint: TPaintBox;
    FPingPaint: TPaintBox;
    FUiTimer: TTimer;
    FMeterTimer: TTimer;
    FCards: array[0..4] of TDashboardCard;
    FLiveOn: Boolean;
    FPingHistory: TArray<TPingHistoryEntry>;
    FWindowDpi: Integer;
    procedure UiTimerTick(Sender: TObject);
    procedure MeterTimerTick(Sender: TObject);
    procedure HeaderPaint(Sender: TObject);
    procedure CpuPaint(Sender: TObject);
    procedure MemPaint(Sender: TObject);
    procedure QueuePaint(Sender: TObject);
    procedure PowerPaint(Sender: TObject);
    procedure PingPaint(Sender: TObject);
    procedure LayoutContent;
    procedure RefreshData;
    procedure ApplyDonutLevels;
    procedure ApplyTheme;
    procedure ApplyDpiChrome;
    procedure ApplySavedDipBounds;
    function WindowDpi: Integer;
    function CurrentMetrics: THudMetrics;
    procedure WMSettingChange(var Message: TWMSettingChange); message WM_SETTINGCHANGE;
    procedure WMDpiChanged(var Message: TMessage); message WM_DPICHANGED;
    function ProductVersionText: string;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent; APipeline: TDisplayPipeline;
      AHistory: TDashboardHistory; ACollector: TMetricsCollector;
      ASettings: TAppSettings); reintroduce;
    procedure PersistDashboardDip;
  end;

implementation

{$R *.dfm}

uses
  uAppStrings;

constructor TDashboardForm.Create(AOwner: TComponent; APipeline: TDisplayPipeline;
  AHistory: TDashboardHistory; ACollector: TMetricsCollector;
  ASettings: TAppSettings);
begin
  FPipeline := APipeline;
  FHistory := AHistory;
  FCollector := ACollector;
  FSettings := ASettings;
  inherited Create(AOwner);
end;

procedure TDashboardForm.FormCreate(Sender: TObject);
var
  i: Integer;
  Pal: THudPalette;
begin
  Pal := HudPalette;
  Scaled := False;
  Caption := S('dash.title');
  Color := Pal.Bg;
  DoubleBuffered := True;
  Position := poDesigned;
  if HandleAllocated then
    FWindowDpi := MonitorDpiForWindow(Handle)
  else
    FWindowDpi := MonitorDpiForWindow(0);
  if FWindowDpi < 1 then
    FWindowDpi := 96;
  ApplyDpiChrome;
  ApplySavedDipBounds;

  FHeaderPaint := TPaintBox.Create(Self);
  FHeaderPaint.Parent := Self;
  FHeaderPaint.Align := alTop;
  FHeaderPaint.Height := CurrentMetrics.HeaderHeight + CurrentMetrics.AccentLine;
  FHeaderPaint.OnPaint := HeaderPaint;

  for i := 0 to 4 do
  begin
    FCards[i] := TDashboardCard.Create(Self);
    FCards[i].Parent := Self;
    FCards[i].History := FHistory;
    FCards[i].AxisNow := S('dash.axis_now');
    FCards[i].Axis5m := S('dash.axis_5m');
  end;
  FCards[0].Title := S('dash.cpu');
  FCards[0].Lane := dlCpu;
  FCards[0].Accent := Pal.Cpu;
  FCards[1].Title := S('dash.mem');
  FCards[1].Lane := dlMem;
  FCards[1].Accent := Pal.Mem;
  FCards[2].Title := S('dash.swap');
  FCards[2].Lane := dlSwap;
  FCards[2].Accent := Pal.Swap;
  FCards[3].Title := S('dash.disk');
  FCards[3].Dual := True;
  FCards[3].Lane := dlDiskRead;
  FCards[3].Lane2 := dlDiskWrite;
  FCards[3].Accent := Pal.Disk;
  FCards[3].Accent2 := Pal.DiskInner;
  FCards[3].LineStyle := lsSolid;
  FCards[3].LineStyle2 := lsSolid;
  FCards[3].Legend1 := S('dash.lg_read');
  FCards[3].Legend2 := S('dash.lg_write');
  FCards[4].Title := S('dash.net');
  FCards[4].Dual := True;
  FCards[4].Lane := dlNetIn;
  FCards[4].Lane2 := dlNetOut;
  FCards[4].Accent := Pal.Net;
  FCards[4].Accent2 := Pal.NetInner;
  FCards[4].LineStyle := lsSolid;
  FCards[4].LineStyle2 := lsSolid;
  FCards[4].Legend1 := S('dash.lg_in');
  FCards[4].Legend2 := S('dash.lg_out');

  FCpuPaint := TPaintBox.Create(Self);
  FCpuPaint.Parent := Self;
  FCpuPaint.OnPaint := CpuPaint;
  FMemPaint := TPaintBox.Create(Self);
  FMemPaint.Parent := Self;
  FMemPaint.OnPaint := MemPaint;
  FQueuePaint := TPaintBox.Create(Self);
  FQueuePaint.Parent := Self;
  FQueuePaint.OnPaint := QueuePaint;
  FPowerPaint := TPaintBox.Create(Self);
  FPowerPaint.Parent := Self;
  FPowerPaint.OnPaint := PowerPaint;
  FPingPaint := TPaintBox.Create(Self);
  FPingPaint.Parent := Self;
  FPingPaint.OnPaint := PingPaint;

  FUiTimer := TTimer.Create(Self);
  FUiTimer.Enabled := False;
  FUiTimer.Interval := 1000;
  FUiTimer.OnTimer := UiTimerTick;
  FMeterTimer := TTimer.Create(Self);
  FMeterTimer.Enabled := False;
  FMeterTimer.Interval := 200;
  FMeterTimer.OnTimer := MeterTimerTick;
  FLiveOn := True;

  LayoutContent;
  ApplyTheme;
end;

procedure TDashboardForm.CreateWnd;
begin
  inherited;
  if FWindowDpi < 1 then
  begin
    FWindowDpi := MonitorDpiForWindow(Handle);
    if FWindowDpi < 1 then
      FWindowDpi := 96;
  end;
  ApplyHudTitleBar(Handle);
end;

function TDashboardForm.WindowDpi: Integer;
begin
  if FWindowDpi > 0 then
    Result := FWindowDpi
  else if HandleAllocated then
    Result := MonitorDpiForWindow(Handle)
  else
    Result := MonitorDpiForWindow(0);
  if Result < 1 then
    Result := 96;
end;

function TDashboardForm.CurrentMetrics: THudMetrics;
begin
  Result := HudMetrics(WindowDpi);
end;

procedure TDashboardForm.ApplyDpiChrome;
var
  Dpi: Integer;
  Met: THudMetrics;
begin
  Dpi := WindowDpi;
  Met := HudMetrics(Dpi);
  Constraints.MinWidth := ScalePx(1000, Dpi);
  Constraints.MinHeight := ScalePx(900, Dpi);
  if FHeaderPaint <> nil then
    FHeaderPaint.Height := Met.HeaderHeight + Met.AccentLine;
end;

procedure TDashboardForm.ApplySavedDipBounds;
var
  Dpi: Integer;
begin
  if FSettings = nil then
    Exit;
  Dpi := WindowDpi;
  { Restore the normal (restored) rectangle first, then maximize if saved. }
  WindowState := wsNormal;
  SetBounds(ScalePx(FSettings.DashboardX, Dpi), ScalePx(FSettings.DashboardY, Dpi),
    ScalePx(FSettings.DashboardW, Dpi), ScalePx(FSettings.DashboardH, Dpi));
  if FSettings.DashboardMaximized then
    WindowState := wsMaximized;
end;

procedure TDashboardForm.PersistDashboardDip;
var
  Dpi: Integer;
  Wp: TWindowPlacement;
  R: TRect;
begin
  if FSettings = nil then
    Exit;
  Dpi := WindowDpi;
  FillChar(Wp, SizeOf(Wp), 0);
  Wp.length := SizeOf(Wp);
  { rcNormalPosition is the restore size even while maximized. Left/Top/Width/Height
    while maximized would overwrite that with the full-screen frame. }
  if HandleAllocated and GetWindowPlacement(Handle, Wp) then
  begin
    R := Wp.rcNormalPosition;
    FSettings.DashboardX := DipFromPx(R.Left, Dpi);
    FSettings.DashboardY := DipFromPx(R.Top, Dpi);
    FSettings.DashboardW := DipFromPx(R.Right - R.Left, Dpi);
    FSettings.DashboardH := DipFromPx(R.Bottom - R.Top, Dpi);
    FSettings.DashboardMaximized :=
      (Wp.showCmd = SW_SHOWMAXIMIZED) or
      ((Wp.showCmd = SW_SHOWMINIMIZED) and
        ((Wp.flags and WPF_RESTORETOMAXIMIZED) <> 0));
  end
  else
  begin
    if WindowState = wsNormal then
    begin
      FSettings.DashboardX := DipFromPx(Left, Dpi);
      FSettings.DashboardY := DipFromPx(Top, Dpi);
      FSettings.DashboardW := DipFromPx(Width, Dpi);
      FSettings.DashboardH := DipFromPx(Height, Dpi);
    end;
    FSettings.DashboardMaximized := WindowState = wsMaximized;
  end;
end;

procedure TDashboardForm.WMDpiChanged(var Message: TMessage);
var
  Suggested: TRect;
begin
  FWindowDpi := LoWord(Message.WParam);
  if FWindowDpi < 1 then
    FWindowDpi := MonitorDpiForWindow(Handle);
  ApplyDpiChrome;
  if Message.LParam <> 0 then
  begin
    Suggested := PRect(Message.LParam)^;
    SetBounds(Suggested.Left, Suggested.Top,
      Suggested.Right - Suggested.Left, Suggested.Bottom - Suggested.Top);
  end;
  LayoutContent;
  ApplyTheme;
  Invalidate;
  Message.Result := 0;
end;

procedure TDashboardForm.ApplyTheme;
var
  Pal: THudPalette;
  i: Integer;
begin
  Pal := HudPalette;
  Color := Pal.Bg;
  ApplyHudTitleBar(Handle);
  if FCards[0] = nil then
    Exit;
  FCards[0].Accent := Pal.Cpu;
  FCards[1].Accent := Pal.Mem;
  FCards[2].Accent := Pal.Swap;
  FCards[3].Accent := Pal.Disk;
  FCards[3].Accent2 := Pal.DiskInner;
  FCards[4].Accent := Pal.Net;
  FCards[4].Accent2 := Pal.NetInner;
  for i := 0 to 4 do
  begin
    FCards[i].Color := Pal.Bg;
    FCards[i].Invalidate;
  end;
  if FHeaderPaint <> nil then
    FHeaderPaint.Invalidate;
  if FCpuPaint <> nil then
    FCpuPaint.Invalidate;
  if FMemPaint <> nil then
    FMemPaint.Invalidate;
  if FQueuePaint <> nil then
    FQueuePaint.Invalidate;
  if FPowerPaint <> nil then
    FPowerPaint.Invalidate;
  if FPingPaint <> nil then
    FPingPaint.Invalidate;
  Invalidate;
end;

procedure TDashboardForm.WMSettingChange(var Message: TWMSettingChange);
begin
  inherited;
  if (Message.Section <> nil) and
    SameText(string(Message.Section), 'ImmersiveColorSet') then
    ApplyTheme;
end;

function TDashboardForm.ProductVersionText: string;
begin
  Result := GetProductVersionText;
end;

procedure TDashboardForm.LayoutContent;
var
  Met: THudMetrics;
  Dpi, LeftColW, RightColW, SideX, Y, i, RowH, BodyH, BodyTop: Integer;
  Extra, MinRight, MinLeft, MinBody, MinRow, MinGraph: Integer;
  Heights: array[0..4] of Integer;
begin
  if (FHeaderPaint = nil) or (FCards[0] = nil) or (FCpuPaint = nil) or
    (FPingPaint = nil) then
    Exit;
  Dpi := WindowDpi;
  Met := HudMetrics(Dpi);
  MinRight := ScalePx(280, Dpi);
  MinLeft := ScalePx(480, Dpi);
  MinGraph := ScalePx(640, Dpi);
  MinBody := ScalePx(400, Dpi);
  MinRow := ScalePx(96, Dpi);
  RightColW := Met.SideColWidth;
  if ClientWidth - Met.Margin * 2 - Met.CardGap - RightColW < MinGraph then
    RightColW := ClientWidth - Met.Margin * 2 - Met.CardGap - MinGraph;
  if RightColW < MinRight then
    RightColW := MinRight;
  LeftColW := ClientWidth - Met.Margin * 2 - Met.CardGap - RightColW;
  if LeftColW < MinLeft then
    LeftColW := MinLeft;
  BodyTop := FHeaderPaint.Height + Met.Margin;
  BodyH := ClientHeight - BodyTop - Met.Margin;
  if BodyH < MinBody then
    BodyH := MinBody;
  { Same five row heights for left sections and facing right subsections. }
  RowH := (BodyH - Met.CardGap * 4) div 5;
  if RowH < MinRow then
    RowH := MinRow;
  Extra := BodyH - Met.CardGap * 4 - RowH * 5;
  if Extra < 0 then
    Extra := 0;
  for i := 0 to 4 do
  begin
    Heights[i] := RowH;
    if Extra > 0 then
    begin
      Inc(Heights[i]);
      Dec(Extra);
    end;
  end;

  Y := BodyTop;
  for i := 0 to 4 do
  begin
    FCards[i].SetBounds(Met.Margin, Y, LeftColW, Heights[i]);
    Inc(Y, Heights[i] + Met.CardGap);
  end;

  SideX := Met.Margin + LeftColW + Met.CardGap;
  Y := BodyTop;
  FCpuPaint.SetBounds(SideX, Y, RightColW, Heights[0]);
  Inc(Y, Heights[0] + Met.CardGap);
  FMemPaint.SetBounds(SideX, Y, RightColW, Heights[1]);
  Inc(Y, Heights[1] + Met.CardGap);
  FPowerPaint.Visible := True;
  FPowerPaint.SetBounds(SideX, Y, RightColW, Heights[2]);
  Inc(Y, Heights[2] + Met.CardGap);
  FQueuePaint.SetBounds(SideX, Y, RightColW, Heights[3]);
  Inc(Y, Heights[3] + Met.CardGap);
  FPingPaint.SetBounds(SideX, Y, RightColW, Heights[4]);
end;

procedure TDashboardForm.ApplyDonutLevels;
begin
  if (FPipeline = nil) or (FCards[0] = nil) then
    Exit;
  { Ballistic meter values (gadget follow), not the 1 Hz digit snapshot. }
  FCards[0].Level := Clamp01(FPipeline.State.Cpu);
  FCards[1].Level := Clamp01(FPipeline.State.Mem);
  FCards[2].Level := Clamp01(FPipeline.State.Swap);
  FCards[3].Level := Clamp01(FPipeline.State.DiskRead);
  FCards[3].Level2 := Clamp01(FPipeline.State.DiskWrite);
  FCards[4].Level := Clamp01(FPipeline.State.NetIn);
  FCards[4].Level2 := Clamp01(FPipeline.State.NetOut);
end;

procedure TDashboardForm.RefreshData;
var
  Snap: TMetricsSnapshot;
  i: Integer;
begin
  if (FPipeline = nil) or (FCollector = nil) then
    Exit;
  Snap := FPipeline.LastSnap;
  FCards[0].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.CpuDigit) * 100)]);
  FCards[1].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.MemDigit) * 100)]);
  FCards[2].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.SwapDigit) * 100)]);
  FCards[3].Value := FormatRateBps(Snap.DiskReadBps);
  FCards[3].Value2 := FormatRateBps(Snap.DiskWriteBps);
  FCards[4].Value := FormatRateBps(Snap.NetInBps);
  FCards[4].Value2 := FormatRateBps(Snap.NetOutBps);
  ApplyDonutLevels;
  FCollector.CopyPingHistory(FPingHistory);
  for i := 0 to 4 do
    FCards[i].Invalidate;
  FCpuPaint.Invalidate;
  FMemPaint.Invalidate;
  FQueuePaint.Invalidate;
  FPowerPaint.Invalidate;
  FPingPaint.Invalidate;
  FHeaderPaint.Invalidate;
end;

procedure TDashboardForm.MeterTimerTick(Sender: TObject);
var
  i: Integer;
begin
  if not Visible then
    Exit;
  ApplyDonutLevels;
  for i := 0 to 4 do
    FCards[i].InvalidateMeter;
  if FPowerPaint <> nil then
    FPowerPaint.Invalidate;
end;

procedure TDashboardForm.UiTimerTick(Sender: TObject);
begin
  FLiveOn := not FLiveOn;
  RefreshData;
end;

procedure TDashboardForm.HeaderPaint(Sender: TObject);
begin
  DrawHudHeader(FHeaderPaint.Canvas, FHeaderPaint.ClientRect,
    'DISKLED HUD', S('dash.live'), ProductVersionText, FLiveOn,
    HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.CpuPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawCpuPanel(FCpuPaint.Canvas, FCpuPaint.ClientRect, FPipeline.LastSnap,
    S('dash.cpu'), S('dash.cpu_name'), S('dash.cpu_cores'), S('dash.cpu_clock'),
    S('dash.cpu_user'), S('dash.cpu_kernel'), HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.MemPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawMemAmounts(FMemPaint.Canvas, FMemPaint.ClientRect, FPipeline.LastSnap,
    S('dash.mem'), S('dash.ram'), S('dash.swap'), S('dash.mem_commit'),
    S('dash.mem_used'), S('dash.mem_standby'), S('dash.mem_free'),
    HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.QueuePaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawDiskQueue(FQueuePaint.Canvas, FQueuePaint.ClientRect, FPipeline.LastSnap,
    S('dash.queue'), S('dash.queue_depth'), S('dash.iops_read'),
    S('dash.iops_write'), S('dash.disk_active'), S('dash.queue_word'),
    S('dash.latency'), HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.PowerPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawPowerPanel(FPowerPaint.Canvas, FPowerPaint.ClientRect, FPipeline.LastSnap,
    FPipeline.State.AudioL, FPipeline.State.AudioR,
    S('dash.power'), S('dash.power_source'), S('dash.power_ac'),
    S('dash.power_battery'), S('dash.power_unknown'), S('dash.power_remain'),
    S('dash.audio'), S('dash.audio_l'), S('dash.audio_r'),
    HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.PingPaint(Sender: TObject);
var
  Snap: TMetricsSnapshot;
begin
  if FPipeline = nil then
    Exit;
  Snap := FPipeline.LastSnap;
  DrawPingPanel(FPingPaint.Canvas, FPingPaint.ClientRect, Snap, FPingHistory,
    S('dash.ping'), S('dash.ping_time'), S('dash.ping_target'),
    S('dash.ping_rtt'), S('dash.ping_status'), HudPalette, CurrentMetrics);
end;

procedure TDashboardForm.FormShow(Sender: TObject);
begin
  FUiTimer.Enabled := True;
  FMeterTimer.Enabled := True;
  RefreshData;
end;

procedure TDashboardForm.FormHide(Sender: TObject);
begin
  FUiTimer.Enabled := False;
  FMeterTimer.Enabled := False;
  PersistDashboardDip;
  if FSettings <> nil then
  try
    FSettings.Save;
  except
  end;
end;

procedure TDashboardForm.FormResize(Sender: TObject);
begin
  LayoutContent;
end;

procedure TDashboardForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FSettings <> nil then
    PersistDashboardDip;
  CanClose := True;
end;

procedure TDashboardForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FSettings <> nil then
    FSettings.DashboardOpen := False;
  Action := caHide;
end;

end.
