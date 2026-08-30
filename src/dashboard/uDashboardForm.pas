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
  uMetricsTypes;

{ Dashboard regions (docs/DESIGN.md, .cursor/rules/dashboard-regions.mdc):
  ヘッダー
  左カラム — セクション × 5 (ドーナツグラフ | 履歴グラフ)
  右カラム — サブセクション × 5 (CPU / メモリ / 電源 / ディスクキュー / Ping)
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
    FCards: array[0..4] of TDashboardCard;
    FLiveOn: Boolean;
    FPingHistory: TArray<TPingHistoryEntry>;
    procedure UiTimerTick(Sender: TObject);
    procedure HeaderPaint(Sender: TObject);
    procedure CpuPaint(Sender: TObject);
    procedure MemPaint(Sender: TObject);
    procedure QueuePaint(Sender: TObject);
    procedure PowerPaint(Sender: TObject);
    procedure PingPaint(Sender: TObject);
    procedure LayoutContent;
    procedure RefreshData;
    procedure ApplyTheme;
    procedure WMSettingChange(var Message: TWMSettingChange); message WM_SETTINGCHANGE;
    function ProductVersionText: string;
  protected
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent; APipeline: TDisplayPipeline;
      AHistory: TDashboardHistory; ACollector: TMetricsCollector;
      ASettings: TAppSettings); reintroduce;
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
  Caption := S('dash.title');
  Color := Pal.Bg;
  DoubleBuffered := True;
  Position := poDesigned;
  Constraints.MinWidth := 1280;
  Constraints.MinHeight := 960;
  if FSettings <> nil then
  begin
    SetBounds(FSettings.DashboardX, FSettings.DashboardY,
      FSettings.DashboardW, FSettings.DashboardH);
  end;

  FHeaderPaint := TPaintBox.Create(Self);
  FHeaderPaint.Parent := Self;
  FHeaderPaint.Align := alTop;
  FHeaderPaint.Height := HudMetrics.HeaderHeight + HudMetrics.AccentLine;
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
  FUiTimer.Interval := 1000;
  FUiTimer.OnTimer := UiTimerTick;
  FLiveOn := True;

  LayoutContent;
  ApplyTheme;
end;

procedure TDashboardForm.CreateWnd;
begin
  inherited;
  ApplyHudTitleBar(Handle);
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
  LeftColW, RightColW, SideX, Y, i, RowH, BodyH, BodyTop: Integer;
  Extra: Integer;
  Heights: array[0..4] of Integer;
begin
  if (FHeaderPaint = nil) or (FCards[0] = nil) or (FCpuPaint = nil) or
    (FPingPaint = nil) then
    Exit;
  Met := HudMetrics;
  RightColW := Met.SideColWidth;
  if ClientWidth - Met.Margin * 2 - Met.CardGap - RightColW < 640 then
    RightColW := ClientWidth - Met.Margin * 2 - Met.CardGap - 640;
  if RightColW < 280 then
    RightColW := 280;
  LeftColW := ClientWidth - Met.Margin * 2 - Met.CardGap - RightColW;
  if LeftColW < 480 then
    LeftColW := 480;
  BodyTop := FHeaderPaint.Height + Met.Margin;
  BodyH := ClientHeight - BodyTop - Met.Margin;
  if BodyH < 400 then
    BodyH := 400;
  { Same five row heights for left sections and facing right subsections. }
  RowH := (BodyH - Met.CardGap * 4) div 5;
  if RowH < 96 then
    RowH := 96;
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

procedure TDashboardForm.RefreshData;
var
  Snap: TMetricsSnapshot;
  i: Integer;
begin
  if (FPipeline = nil) or (FCollector = nil) then
    Exit;
  Snap := FPipeline.LastSnap;
  FCards[0].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.CpuDigit) * 100)]);
  FCards[0].Level := Clamp01(FPipeline.State.CpuDigit);
  FCards[1].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.MemDigit) * 100)]);
  FCards[1].Level := Clamp01(FPipeline.State.MemDigit);
  FCards[2].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.SwapDigit) * 100)]);
  FCards[2].Level := Clamp01(FPipeline.State.SwapDigit);
  FCards[3].Value := FormatRateBps(Snap.DiskReadBps);
  FCards[3].Value2 := FormatRateBps(Snap.DiskWriteBps);
  FCards[3].Level := Clamp01(FPipeline.State.DiskRead);
  FCards[3].Level2 := Clamp01(FPipeline.State.DiskWrite);
  FCards[4].Value := FormatRateBps(Snap.NetInBps);
  FCards[4].Value2 := FormatRateBps(Snap.NetOutBps);
  FCards[4].Level := Clamp01(FPipeline.State.NetIn);
  FCards[4].Level2 := Clamp01(FPipeline.State.NetOut);
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

procedure TDashboardForm.UiTimerTick(Sender: TObject);
begin
  FLiveOn := not FLiveOn;
  RefreshData;
end;

procedure TDashboardForm.HeaderPaint(Sender: TObject);
begin
  DrawHudHeader(FHeaderPaint.Canvas, FHeaderPaint.ClientRect,
    'DISKLED HUD', S('dash.live'), ProductVersionText, FLiveOn,
    HudPalette, HudMetrics);
end;

procedure TDashboardForm.CpuPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawCpuPanel(FCpuPaint.Canvas, FCpuPaint.ClientRect, FPipeline.LastSnap,
    S('dash.cpu'), S('dash.cpu_name'), S('dash.cpu_cores'), S('dash.cpu_clock'),
    S('dash.cpu_user'), S('dash.cpu_kernel'), HudPalette, HudMetrics);
end;

procedure TDashboardForm.MemPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawMemAmounts(FMemPaint.Canvas, FMemPaint.ClientRect, FPipeline.LastSnap,
    S('dash.mem'), S('dash.ram'), S('dash.swap'), S('dash.mem_commit'),
    S('dash.mem_used'), S('dash.mem_standby'), S('dash.mem_free'),
    HudPalette, HudMetrics);
end;

procedure TDashboardForm.QueuePaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawDiskQueue(FQueuePaint.Canvas, FQueuePaint.ClientRect, FPipeline.LastSnap,
    S('dash.queue'), S('dash.queue_depth'), S('dash.iops_read'),
    S('dash.iops_write'), S('dash.disk_active'), HudPalette, HudMetrics);
end;

procedure TDashboardForm.PowerPaint(Sender: TObject);
begin
  if FPipeline = nil then
    Exit;
  DrawPowerPanel(FPowerPaint.Canvas, FPowerPaint.ClientRect, FPipeline.LastSnap,
    S('dash.power'), S('dash.power_source'), S('dash.power_ac'),
    S('dash.power_battery'), S('dash.power_unknown'), S('dash.power_remain'),
    HudPalette, HudMetrics);
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
    S('dash.ping_rtt'), S('dash.ping_status'), HudPalette, HudMetrics);
end;

procedure TDashboardForm.FormShow(Sender: TObject);
begin
  FUiTimer.Enabled := True;
  RefreshData;
end;

procedure TDashboardForm.FormHide(Sender: TObject);
begin
  FUiTimer.Enabled := False;
end;

procedure TDashboardForm.FormResize(Sender: TObject);
begin
  LayoutContent;
end;

procedure TDashboardForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if FSettings <> nil then
  begin
    FSettings.DashboardX := Left;
    FSettings.DashboardY := Top;
    FSettings.DashboardW := Width;
    FSettings.DashboardH := Height;
  end;
  CanClose := True;
end;

procedure TDashboardForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if FSettings <> nil then
    FSettings.DashboardOpen := False;
  Action := caHide;
end;

end.
