unit uDashboardForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.Types,
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
  uDpiScale,
  uProcessCollector,
  uHoverTip,
  uThemedHudForm;

{ Dashboard regions (docs/DESIGN.md, .cursor/rules/dashboard-regions.mdc):
  ヘッダー
  タブ行 (概要 / プロセス)
  概要ページ:
    左カラム — セクション × 5 (ドーナツグラフ | 履歴グラフ)
    右カラム — サブセクション × 5 (CPU / メモリ / 電源（左：電源 | 右：音量） / ディスクキュー / Ping)
  プロセスページ: リソース別 TOP5
  Do not put subsection facts inside a left-column section. }
type
  TDashboardPage = (dpOverview, dpProcess);

  TDashboardForm = class(TThemedHudForm)
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
    FTabPaint: TPaintBox;
    FTabRects: TArray<TRect>;
    FIntervalRects: TArray<TRect>;
    FPage: TDashboardPage;
    FProcessPaint: TPaintBox;
    FProcess: TProcessCollector;
    FProcessIcons: TProcessIconCache;
    { Per column, rectangle and tooltip of each drawn entry (from the last
      ProcessPaint) for hover hints. }
    FProcRects: array[TProcessResource] of TArray<TRect>;
    FProcTips: array[TProcessResource] of TArray<string>;
    FProcessPaintWndProc: TWndMethod;
    { Native tracked tooltip shared with the gadget window's look (uHoverTip).
      FProcHoverKey = Ord(resource) * CProcessTopMax + row, -1 when none. }
    FProcTip: THoverTip;
    FProcTipDelay: TTimer;
    FProcHoverKey: Integer;
    { "Stop" chosen in the refresh choice: the list stays frozen until another
      period is picked or the page is left. Not saved. }
    FProcPaused: Boolean;
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
    procedure ProcessMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ProcessPaintWndProc(var Message: TMessage);
    procedure ProcTipDelayTick(Sender: TObject);
    procedure HideProcTip;
    function ProcTipText(AKey: Integer): string;
    procedure UiTimerTick(Sender: TObject);
    procedure MeterTimerTick(Sender: TObject);
    procedure HeaderPaint(Sender: TObject);
    procedure TabPaint(Sender: TObject);
    procedure TabMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SetPage(APage: TDashboardPage);
    procedure ApplyPageVisibility;
    procedure ProcessPaint(Sender: TObject);
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
    procedure ApplyDpiChromeFor(const AWork: TRect);
    procedure ApplySavedDipBounds;
    function CurrentWorkArea: TRect;
    procedure EffectiveMinSize(ADpi: Integer; const AWork: TRect;
      out AMinW, AMinH: Integer);
    procedure ClampSizeToWorkArea(var AWidth, AHeight: Integer; const AWork: TRect);
    function WindowDpi: Integer;
    function CurrentMetrics: THudMetrics;
    procedure WMDpiChanged(var Message: TMessage); message WM_DPICHANGED;
    procedure WMDisplayChange(var Message: TMessage); message WM_DISPLAYCHANGE;
    function ProductVersionText: string;
  protected
    procedure ApplyPalette; override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent; APipeline: TDisplayPipeline;
      AHistory: TDashboardHistory; ACollector: TMetricsCollector;
      ASettings: TAppSettings); reintroduce;
    destructor Destroy; override;
    procedure PersistDashboardDip;
    { Bring the window back onto a visible monitor if a display change left it
      off-screen. No-op while maximized/minimized. Called on every show and from
      the gadget's "Reset position" menu item. }
    procedure ClampIntoView;
  end;

implementation

{$R *.dfm}

uses
  Winapi.MultiMon,
  uAppStrings,
  uWindowPlacement;

const
  { Process page refresh choices in seconds (uSettings normalizes to these). }
  CProcessIntervals: array[0..2] of Integer = (3, 5, 10);
  { Entries per process column at the default size and below. }
  CProcessTopShown = 5;

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

destructor TDashboardForm.Destroy;
begin
  { Stops and joins the worker thread. Done before inherited so a late
    FormHide during teardown sees nil rather than a freed collector. }
  FreeAndNil(FProcess);
  FreeAndNil(FProcessIcons);
  FreeAndNil(FProcTip);
  inherited;
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
  { Position before sizing the chrome: CurrentWorkArea falls back to
    BoundsRect when there's no handle yet, so it only resolves the correct
    (target) monitor once ApplySavedDipBounds has moved Left/Top there. }
  ApplySavedDipBounds;
  ApplyDpiChrome;

  FHeaderPaint := TPaintBox.Create(Self);
  FHeaderPaint.Parent := Self;
  FHeaderPaint.Align := alTop;
  FHeaderPaint.Height := CurrentMetrics.HeaderHeight + CurrentMetrics.AccentLine;
  FHeaderPaint.OnPaint := HeaderPaint;

  { Two alTop controls: place the tab row below the header before aligning it so
    the VCL keeps header-then-tabs order. }
  FTabPaint := TPaintBox.Create(Self);
  FTabPaint.Parent := Self;
  FTabPaint.Top := FHeaderPaint.Top + FHeaderPaint.Height;
  FTabPaint.Height := CurrentMetrics.TabHeight;
  FTabPaint.Align := alTop;
  FTabPaint.OnPaint := TabPaint;
  FTabPaint.OnMouseDown := TabMouseDown;
  FPage := dpOverview;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  for i := 0 to 4 do
  begin
    FCards[i] := TDashboardCard.Create(Self);
    FCards[i].Parent := Self;
    FCards[i].History := FHistory;
    FCards[i].AxisNow := S('dash.axis_now');
    FCards[i].Axis5m := S('dash.axis_5m');
  end;
  FCards[0].Title := S('dash.cpu_gpu');
  FCards[0].Dual := True;
  FCards[0].Lane := dlCpu;
  FCards[0].Lane2 := dlGpu;
  FCards[0].Accent := Pal.Cpu;
  FCards[0].Accent2 := Pal.Gpu;
  FCards[0].LineStyle := lsSolid;
  FCards[0].LineStyle2 := lsSolid;
  FCards[0].Legend1 := S('dash.cpu');
  FCards[0].Legend2 := S('dash.gpu');
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
  FProcessPaint := TPaintBox.Create(Self);
  FProcessPaint.Parent := Self;
  FProcessPaint.OnPaint := ProcessPaint;
  FProcessPaint.OnMouseMove := ProcessMouseMove;
  FProcessPaintWndProc := FProcessPaint.WindowProc;
  FProcessPaint.WindowProc := ProcessPaintWndProc;
  FProcTip := THoverTip.Create;
  FProcTipDelay := TTimer.Create(Self);
  FProcTipDelay.Enabled := False;
  if Application.HintPause > 0 then
    FProcTipDelay.Interval := Application.HintPause
  else
    FProcTipDelay.Interval := 500;
  FProcTipDelay.OnTimer := ProcTipDelayTick;
  FProcHoverKey := -1;
  FProcess := TProcessCollector.Create;
  FProcessIcons := TProcessIconCache.Create;
  if FSettings <> nil then
    FProcess.SetInterval(FSettings.DashboardProcessIntervalSec);
  ApplyPageVisibility;

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
  inherited; { TThemedHudForm.CreateWnd applies the DWM title bar }
  if FWindowDpi < 1 then
  begin
    FWindowDpi := MonitorDpiForWindow(Handle);
    if FWindowDpi < 1 then
      FWindowDpi := 96;
  end;
end;

procedure TDashboardForm.ApplyPalette;
begin
  ApplyTheme;
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

function TDashboardForm.CurrentWorkArea: TRect;
begin
  if HandleAllocated then
    Result := WorkAreaForWindow(Handle)
  else
    { No HWND yet (e.g. during FormCreate, before ApplySavedDipBounds has
      positioned the window): WorkAreaForWindow(0) would silently fall back
      to the primary monitor regardless of where the window is about to
      land. BoundsRect already reflects Left/Top/Width/Height as VCL
      properties even without a handle, so resolve the monitor from that
      instead -- correct as soon as the caller has set the target position. }
    Result := WorkAreaForRect(BoundsRect);
end;

{ Minimum window size in physical pixels, per axis independently:
  1) ideal 1000x800 DIP scaled to the current DPI, then
  2) shrunk to the target monitor's work area if it would not fit (this is the
     bug fix — a fixed DIP*DPI floor made the dashboard unshrinkable below the
     screen at 150/200%), but never
  3) below an absolute 800x600 DIP floor (matches uSettings.Normalize and the
     .dfm design-time Constraints). On a monitor whose work area is smaller
     than that floor the floor still wins; revisit the floor if that surfaces. }
procedure TDashboardForm.EffectiveMinSize(ADpi: Integer; const AWork: TRect;
  out AMinW, AMinH: Integer);
var
  FloorW, FloorH, WorkW, WorkH: Integer;
begin
  AMinW := ScalePx(1000, ADpi);
  AMinH := ScalePx(800, ADpi);
  WorkW := AWork.Right - AWork.Left;
  WorkH := AWork.Bottom - AWork.Top;
  if (WorkW > 0) and (AMinW > WorkW) then
    AMinW := WorkW;
  if (WorkH > 0) and (AMinH > WorkH) then
    AMinH := WorkH;
  FloorW := ScalePx(800, ADpi);
  FloorH := ScalePx(600, ADpi);
  if AMinW < FloorW then
    AMinW := FloorW;
  if AMinH < FloorH then
    AMinH := FloorH;
end;

procedure TDashboardForm.ClampSizeToWorkArea(var AWidth, AHeight: Integer;
  const AWork: TRect);
var
  WorkW, WorkH: Integer;
begin
  WorkW := AWork.Right - AWork.Left;
  WorkH := AWork.Bottom - AWork.Top;
  if (WorkW > 0) and (AWidth > WorkW) then
    AWidth := WorkW;
  if (WorkH > 0) and (AHeight > WorkH) then
    AHeight := WorkH;
end;

procedure TDashboardForm.ApplyDpiChrome;
begin
  ApplyDpiChromeFor(CurrentWorkArea);
end;

{ Same as ApplyDpiChrome, but against a caller-supplied work area instead of
  CurrentWorkArea. WMDpiChanged needs this: while handling the message the
  window's HWND is still associated with the *old* monitor (SetBounds to the
  suggested rect hasn't run yet), so CurrentWorkArea/WorkAreaForWindow(Handle)
  would resolve the wrong screen -- the same reason it already uses
  WorkAreaForRect(Suggested) for its own size clamp a few lines down. }
procedure TDashboardForm.ApplyDpiChromeFor(const AWork: TRect);
var
  Dpi, MinW, MinH: Integer;
  Met: THudMetrics;
begin
  Dpi := WindowDpi;
  Met := HudMetrics(Dpi);
  EffectiveMinSize(Dpi, AWork, MinW, MinH);
  Constraints.MinWidth := MinW;
  Constraints.MinHeight := MinH;
  if FHeaderPaint <> nil then
    FHeaderPaint.Height := Met.HeaderHeight + Met.AccentLine;
  if FTabPaint <> nil then
    FTabPaint.Height := Met.TabHeight;
end;

procedure TDashboardForm.ApplySavedDipBounds;
var
  Dpi, X, Y, W, H, CW, CH: Integer;
begin
  if FSettings = nil then
    Exit;
  Dpi := WindowDpi;
  { Restore the normal (restored) rectangle first, then maximize if saved. }
  WindowState := wsNormal;
  X := ScalePx(FSettings.DashboardX, Dpi);
  Y := ScalePx(FSettings.DashboardY, Dpi);
  W := ScalePx(FSettings.DashboardW, Dpi);
  H := ScalePx(FSettings.DashboardH, Dpi);
  SetBounds(X, Y, W, H);
  { A size saved on a larger/lower-DPI monitor can exceed the current monitor's
    work area — shrink it to fit so the window is not born unshrinkable. }
  CW := W;
  CH := H;
  ClampSizeToWorkArea(CW, CH, CurrentWorkArea);
  if (CW <> W) or (CH <> H) then
    SetBounds(X, Y, CW, CH);
  if FSettings.DashboardMaximized then
    WindowState := wsMaximized;
end;

procedure TDashboardForm.ClampIntoView;
var
  Wp: TWindowPlacement;
  R: TRect;
begin
  if not HandleAllocated then
    Exit;
  FillChar(Wp, SizeOf(Wp), 0);
  Wp.length := SizeOf(Wp);
  if not GetWindowPlacement(Handle, Wp) then
    Exit;
  R := Wp.rcNormalPosition;
  { Only rescue a window that has become completely unreachable (every monitor it
    was on was removed). A window still touching a monitor is left where the user
    put it — including one deliberately straddling two monitors, or one taller
    than the work area (common at 1080p / 150%), which an unconditional clamp
    would yank to the work-area origin on every show. Operating on the restore
    rectangle (not BoundsRect) also covers a maximized or minimized window whose
    restore position is off-screen. }
  if MonitorFromRect(@R, MONITOR_DEFAULTTONULL) <> 0 then
    Exit;
  ClampRectToWindowMonitor(R, Handle);
  if EqualRect(R, Wp.rcNormalPosition) then
    Exit;
  { Only correct the restore rectangle; leave showCmd alone so a minimized or
    maximized window is not disturbed — it simply comes back on-screen when the
    user next restores it. }
  Wp.rcNormalPosition := R;
  SetWindowPlacement(Handle, Wp);
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
  W, H: Integer;
begin
  FWindowDpi := LoWord(Message.WParam);
  if FWindowDpi < 1 then
    FWindowDpi := MonitorDpiForWindow(Handle);
  if Message.LParam <> 0 then
  begin
    Suggested := PRect(Message.LParam)^;
    { Handle is still associated with the old monitor at this point (the
      window hasn't moved yet), so size the chrome against the suggested
      rect's monitor rather than CurrentWorkArea -- same reasoning as the
      size clamp below, which already avoids WorkAreaForWindow(Handle). }
    ApplyDpiChromeFor(WorkAreaForRect(Suggested));
    W := Suggested.Right - Suggested.Left;
    H := Suggested.Bottom - Suggested.Top;
    { The OS-suggested rect only preserves the DIP size; it can still overflow
      the new monitor's work area when moving to a higher scale. }
    ClampSizeToWorkArea(W, H, WorkAreaForRect(Suggested));
    SetBounds(Suggested.Left, Suggested.Top, W, H);
  end
  else
    ApplyDpiChrome;
  LayoutContent;
  ApplyTheme;
  Invalidate;
  Message.Result := 0;
end;

procedure TDashboardForm.WMDisplayChange(var Message: TMessage);
var
  W, H: Integer;
begin
  inherited;
  { A monitor was added/removed or a resolution changed while the dashboard is
    open. Re-tighten the min-size constraints to the (possibly shrunk) work
    area, clamp the current size into it, then pull the window back if it was
    left unreachable (matches TMainForm). }
  ApplyDpiChrome;
  if HandleAllocated and (WindowState = wsNormal) then
  begin
    W := Width;
    H := Height;
    ClampSizeToWorkArea(W, H, CurrentWorkArea);
    if (W <> Width) or (H <> Height) then
      SetBounds(Left, Top, W, H);
  end;
  ClampIntoView;
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
  FCards[0].Accent2 := Pal.Gpu;
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
  if FTabPaint <> nil then
    FTabPaint.Invalidate;
  if FProcessPaint <> nil then
    FProcessPaint.Invalidate;
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
  if (FHeaderPaint = nil) or (FTabPaint = nil) or (FCards[0] = nil) or
    (FCpuPaint = nil) or (FPingPaint = nil) or (FProcessPaint = nil) then
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
  BodyTop := FHeaderPaint.Height + FTabPaint.Height + Met.Margin;
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
  FPowerPaint.SetBounds(SideX, Y, RightColW, Heights[2]);
  Inc(Y, Heights[2] + Met.CardGap);
  FQueuePaint.SetBounds(SideX, Y, RightColW, Heights[3]);
  Inc(Y, Heights[3] + Met.CardGap);
  FPingPaint.SetBounds(SideX, Y, RightColW, Heights[4]);

  { The process page spans both columns of the same body area. }
  FProcessPaint.SetBounds(Met.Margin, BodyTop,
    LeftColW + Met.CardGap + RightColW, BodyH);
end;

procedure TDashboardForm.ApplyPageVisibility;
var
  i: Integer;
  Overview: Boolean;
begin
  Overview := FPage = dpOverview;
  for i := 0 to 4 do
    if FCards[i] <> nil then
      FCards[i].Visible := Overview;
  if FCpuPaint <> nil then
    FCpuPaint.Visible := Overview;
  if FMemPaint <> nil then
    FMemPaint.Visible := Overview;
  if FPowerPaint <> nil then
    FPowerPaint.Visible := Overview;
  if FQueuePaint <> nil then
    FQueuePaint.Visible := Overview;
  if FPingPaint <> nil then
    FPingPaint.Visible := Overview;
  if FProcessPaint <> nil then
    FProcessPaint.Visible := not Overview;
end;

procedure TDashboardForm.SetPage(APage: TDashboardPage);
begin
  if APage = FPage then
    Exit;
  FPage := APage;
  ApplyPageVisibility;
  HideProcTip;
  { Process sampling runs only while its page is on screen. Leaving the page
    discards the list, so a pause doesn't outlive it either. }
  FProcPaused := False;
  if FProcess <> nil then
  begin
    FProcess.SetPaused(False);
    FProcess.SetActive(FPage = dpProcess);
  end;
  if FTabPaint <> nil then
    FTabPaint.Invalidate;
  { Overview widgets skipped repaints while hidden; bring them up to date now. }
  if FPage = dpOverview then
    RefreshData;
end;

procedure TDashboardForm.TabMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  i: Integer;
begin
  if Button <> mbLeft then
    Exit;
  for i := 0 to High(FTabRects) do
    if (i <= Ord(High(TDashboardPage))) and PtInRect(FTabRects[i], Point(X, Y)) then
    begin
      SetPage(TDashboardPage(i));
      Exit;
    end;
  if FPage <> dpProcess then
    Exit;
  for i := 0 to High(FIntervalRects) do
    if PtInRect(FIntervalRects[i], Point(X, Y)) then
    begin
      if i > High(CProcessIntervals) then
        { The trailing "Stop" option freezes the list as it is. }
        FProcPaused := True
      else
      begin
        FProcPaused := False;
        if FSettings <> nil then
          FSettings.DashboardProcessIntervalSec := CProcessIntervals[i];
        if FProcess <> nil then
          FProcess.SetInterval(CProcessIntervals[i]);
      end;
      if FProcess <> nil then
        FProcess.SetPaused(FProcPaused);
      FTabPaint.Invalidate;
      Exit;
    end;
end;

procedure TDashboardForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  N: Integer;
begin
  if (Key <> VK_TAB) or not (ssCtrl in Shift) then
    Exit;
  N := Ord(High(TDashboardPage)) + 1;
  if ssShift in Shift then
    SetPage(TDashboardPage((Ord(FPage) + N - 1) mod N))
  else
    SetPage(TDashboardPage((Ord(FPage) + 1) mod N));
  Key := 0;
end;

procedure TDashboardForm.TabPaint(Sender: TObject);
var
  { The periods, then "Stop". }
  Opts: array[0..High(CProcessIntervals) + 1] of string;
  i, Active, Sec: Integer;
begin
  DrawTabRow(FTabPaint.Canvas, FTabPaint.ClientRect,
    [S('dash.tab_overview'), S('dash.tab_process')], Ord(FPage), HudPalette,
    CurrentMetrics, FTabRects);
  if FPage <> dpProcess then
  begin
    FIntervalRects := nil;
    Exit;
  end;
  Sec := 3;
  if FSettings <> nil then
    Sec := FSettings.DashboardProcessIntervalSec;
  Active := 0;
  for i := 0 to High(CProcessIntervals) do
  begin
    Opts[i] := Format(S('dash.proc_sec'), [CProcessIntervals[i]]);
    if CProcessIntervals[i] = Sec then
      Active := i;
  end;
  Opts[High(Opts)] := S('dash.proc_stop');
  if FProcPaused then
    Active := High(Opts);
  DrawTabChoice(FTabPaint.Canvas, FTabPaint.ClientRect, S('dash.proc_interval'),
    Opts, Active, HudPalette, CurrentMetrics, FIntervalRects);
end;

{ "chrome (12)" for a merged row, the bare name for a single process. }
function ProcessRowName(const AEntry: TProcessTopEntry): string;
begin
  if AEntry.Count > 1 then
    Result := Format('%s (%d)', [AEntry.Name, AEntry.Count])
  else
    Result := AEntry.Name;
end;

{ Non-empty parts joined with a middle dot. }
function JoinDot(const AParts: TArray<string>): string;
var
  Part: string;
begin
  Result := '';
  for Part in AParts do
  begin
    if Part = '' then
      Continue;
    if Result <> '' then
      Result := Result + '  ' + #$00B7 + '  ';
    Result := Result + Part;
  end;
end;

function GroupedCount(AValue: Int64): string;
begin
  Result := Format('%.0n', [AValue * 1.0]);
end;

function ProcessUserText(const AEntry: TProcessTopEntry): string;
begin
  Result := '';
  if not (AEntry.HasDetail and AEntry.Detail.HasToken) then
    Exit;
  if AEntry.Detail.Elevated then
    Result := Format(S('dash.proc_user_admin'), [AEntry.Detail.UserName])
  else
    Result := AEntry.Detail.UserName;
end;

{ Line 2, "what is it": window title, else description, else product name;
  then the company. }
function ProcessRowWhat(const AEntry: TProcessTopEntry): string;
var
  What: string;
begin
  What := AEntry.WindowTitle;
  if AEntry.HasDetail then
  begin
    if What = '' then
      What := AEntry.Detail.Description;
    if What = '' then
      What := AEntry.Detail.ProductName;
    Result := JoinDot([What, AEntry.Detail.Company]);
  end
  else if What <> '' then
    Result := What
  else
    Result := S('dash.proc_noaccess');
end;

{ Line 3, "state": user (admin), commit, handles, threads. }
function ProcessRowStatus(const AEntry: TProcessTopEntry): string;
begin
  Result := JoinDot([ProcessUserText(AEntry),
    S('dash.tip_commit') + ' ' + FormatBytesMB(AEntry.CommitBytes),
    S('dash.tip_handles') + ' ' + GroupedCount(AEntry.Handles),
    S('dash.tip_threads') + ' ' + GroupedCount(AEntry.Threads)]);
end;

{ Everything known about the row, one "label: value" per line. }
function ProcessTooltip(const AEntry: TProcessTopEntry): string;
var
  Lines: TStringList;

  procedure Add(const AKey, AValue: string);
  begin
    if AValue <> '' then
      Lines.Add(S(AKey) + ': ' + AValue);
  end;

begin
  Lines := TStringList.Create;
  try
    Lines.Add(ProcessRowName(AEntry));
    Add('dash.tip_window', AEntry.WindowTitle);
    if AEntry.HasDetail then
    begin
      Add('dash.tip_desc', AEntry.Detail.Description);
      Add('dash.tip_product', AEntry.Detail.ProductName);
      Add('dash.tip_company', AEntry.Detail.Company);
      Add('dash.tip_version', AEntry.Detail.Version);
      Add('dash.tip_copyright', AEntry.Detail.Copyright);
      Add('dash.tip_user', ProcessUserText(AEntry));
      if AEntry.Detail.HasBitness then
        if AEntry.Detail.Is32Bit then
          Add('dash.tip_bitness', '32bit')
        else
          Add('dash.tip_bitness', '64bit');
    end
    else
      Lines.Add(S('dash.proc_noaccess'));
    Add('dash.tip_commit', FormatBytesMB(AEntry.CommitBytes));
    Add('dash.tip_handles', GroupedCount(AEntry.Handles));
    Add('dash.tip_threads', GroupedCount(AEntry.Threads));
    if AEntry.HasDetail then
      Add('dash.tip_path', AEntry.Detail.Path);
    Result := TrimRight(Lines.Text);
  finally
    Lines.Free;
  end;
end;

procedure TDashboardForm.ProcessPaint(Sender: TObject);
var
  Pal: THudPalette;
  Met: THudMetrics;
  ProcTop: TProcessTop;
  Snap: TMetricsSnapshot;
  Rows: TArray<TProcessRowText>;
  Res: TProcessResource;
  i, ColW, X, Slots: Integer;
  Threads: Integer;
  E: TProcessTopEntry;
  SecRect: TRect;
begin
  Pal := HudPalette;
  Met := CurrentMetrics;
  ProcTop := Default(TProcessTop);
  if FProcess <> nil then
    FProcess.CopyTop(ProcTop);
  Snap := Default(TMetricsSnapshot);
  if FPipeline <> nil then
    Snap := FPipeline.LastSnap;
  { PDH reports one busy core as 100%; divide by logical processors for the
    share of the whole machine, as Task Manager's Processes tab does. }
  Threads := Snap.CpuThreads;
  if Threads < 1 then
    Threads := 1;

  { Three tall columns side by side: CPU | Memory | I/O. }
  ColW := (FProcessPaint.ClientWidth - Met.CardGap * 2) div 3;
  X := 0;
  for Res := Low(TProcessResource) to High(TProcessResource) do
  begin
    if Res = High(TProcessResource) then
      SecRect := Rect(X, 0, FProcessPaint.ClientWidth, FProcessPaint.ClientHeight)
    else
      SecRect := Rect(X, 0, X + ColW, FProcessPaint.ClientHeight);
    Inc(X, ColW + Met.CardGap);
    { Five entries by default, more as the window grows taller. Only the
      shown ones are formatted (and get an icon). }
    Slots := ProcessRowSlots(SecRect, CProcessTopShown, CProcessTopMax, Met);
    if Length(ProcTop.Items[Res]) < Slots then
      SetLength(Rows, Length(ProcTop.Items[Res]))
    else
      SetLength(Rows, Slots);
    SetLength(FProcTips[Res], Length(Rows));
    for i := 0 to High(Rows) do
    begin
      E := ProcTop.Items[Res][i];
      Rows[i].Name := ProcessRowName(E);
      Rows[i].Detail := ProcessRowWhat(E);
      Rows[i].Status := ProcessRowStatus(E);
      if E.HasDetail then
        Rows[i].Path := E.Detail.Path;
      FProcTips[Res][i] := ProcessTooltip(E);
      { The painter draws the icon about two text lines tall (~32 DIP); ask for
        that pixel size so it isn't stretched from 32 px at high DPI. An empty
        path gets the stock application icon. }
      if FProcessIcons <> nil then
        Rows[i].Icon := FProcessIcons.IconFor(Rows[i].Path, ScalePx(32, WindowDpi));
      case Res of
        prCpu:
          Rows[i].Values := [Format('%.1f%%', [E.CpuPct / Threads])];
        prMem:
          begin
            if Snap.MemTotalBytes > 0 then
              Rows[i].Values := [FormatBytesMB(E.MemBytes),
                Format('%.1f%%', [E.MemBytes / Snap.MemTotalBytes * 100])]
            else
              Rows[i].Values := [FormatBytesMB(E.MemBytes), string(#$2014)];
          end;
      else
        Rows[i].Values := [FormatRateBps(E.IoReadBps), FormatRateBps(E.IoWriteBps)];
      end;
    end;
    case Res of
      prCpu:
        DrawProcessTop(FProcessPaint.Canvas, SecRect, S('dash.proc_cpu'),
          [S('dash.proc_col_usage')], Rows, ProcTop.Valid, Slots,
          Pal.Cpu, Pal, Met, FProcRects[Res]);
      prMem:
        DrawProcessTop(FProcessPaint.Canvas, SecRect, S('dash.proc_mem'),
          [S('dash.proc_col_used'), S('dash.proc_col_share')], Rows,
          ProcTop.Valid, Slots, Pal.Mem, Pal, Met, FProcRects[Res]);
    else
      DrawProcessTop(FProcessPaint.Canvas, SecRect, S('dash.proc_io'),
        [S('dash.proc_col_read'), S('dash.proc_col_write')], Rows,
        ProcTop.Valid, Slots, Pal.Disk, Pal, Met, FProcRects[Res]);
    end;
  end;
  { Keep an open tooltip in step with the refreshed values. }
  if (FProcTip <> nil) and FProcTip.Visible then
    FProcTip.UpdateText(ProcTipText(FProcHoverKey));
end;

{ Tooltip text of the entry under the hover key, '' if it no longer exists. }
function TDashboardForm.ProcTipText(AKey: Integer): string;
var
  Res: TProcessResource;
  i: Integer;
begin
  Result := '';
  if AKey < 0 then
    Exit;
  Res := TProcessResource(AKey div CProcessTopMax);
  i := AKey mod CProcessTopMax;
  if i <= High(FProcTips[Res]) then
    Result := FProcTips[Res][i];
end;

procedure TDashboardForm.ProcessMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var
  Res: TProcessResource;
  i, Key: Integer;
begin
  Key := -1;
  for Res := Low(TProcessResource) to High(TProcessResource) do
    for i := 0 to High(FProcRects[Res]) do
      if PtInRect(FProcRects[Res][i], Point(X, Y)) then
        Key := Ord(Res) * CProcessTopMax + i;
  if Key < 0 then
  begin
    HideProcTip;
    Exit;
  end;
  if Key = FProcHoverKey then
    Exit;
  { Moved onto another entry: hide, then show its tip after the usual hint
    pause -- the same native tooltip and timing as the gadget window. }
  FProcHoverKey := Key;
  if FProcTip <> nil then
    FProcTip.Hide;
  FProcTipDelay.Enabled := False;
  FProcTipDelay.Enabled := True;
end;

procedure TDashboardForm.ProcTipDelayTick(Sender: TObject);
var
  Tip: string;
begin
  FProcTipDelay.Enabled := False;
  Tip := ProcTipText(FProcHoverKey);
  if (Tip = '') or (FProcTip = nil) then
    Exit;
  FProcTip.SetOwner(Handle);
  FProcTip.ShowAtCursor(Tip);
end;

procedure TDashboardForm.HideProcTip;
begin
  FProcHoverKey := -1;
  if FProcTipDelay <> nil then
    FProcTipDelay.Enabled := False;
  if FProcTip <> nil then
    FProcTip.Hide;
end;

procedure TDashboardForm.ProcessPaintWndProc(var Message: TMessage);
begin
  if Message.Msg = CM_MOUSELEAVE then
    HideProcTip;
  FProcessPaintWndProc(Message);
end;

procedure TDashboardForm.ApplyDonutLevels;
begin
  if (FPipeline = nil) or (FCards[0] = nil) then
    Exit;
  { Ballistic meter values (gadget follow), not the 1 Hz digit snapshot. }
  FCards[0].Level := Clamp01(FPipeline.State.Cpu);
  FCards[0].Level2 := Clamp01(FPipeline.State.Gpu);
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
  FCards[0].Value2 := Format('%d%%', [Round(Clamp01(FPipeline.State.GpuDigit) * 100)]);
  FCards[1].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.MemDigit) * 100)]);
  FCards[2].Value := Format('%d%%', [Round(Clamp01(FPipeline.State.SwapDigit) * 100)]);
  FCards[3].Value := FormatRateBps(Snap.DiskReadBps);
  FCards[3].Value2 := FormatRateBps(Snap.DiskWriteBps);
  FCards[4].Value := FormatRateBps(Snap.NetInBps);
  FCards[4].Value2 := FormatRateBps(Snap.NetOutBps);
  ApplyDonutLevels;
  FCollector.CopyPingHistory(FPingHistory);
  FHeaderPaint.Invalidate;
  { Hidden overview widgets need no repaint; SetPage refreshes them on return.
    History keeps accumulating on the MainForm side, so graphs stay continuous. }
  if FPage <> dpOverview then
  begin
    FProcessPaint.Invalidate;
    Exit;
  end;
  for i := 0 to 4 do
    FCards[i].Invalidate;
  FCpuPaint.Invalidate;
  FMemPaint.Invalidate;
  FQueuePaint.Invalidate;
  FPowerPaint.Invalidate;
  FPingPaint.Invalidate;
end;

procedure TDashboardForm.MeterTimerTick(Sender: TObject);
var
  i: Integer;
begin
  if not Visible or (FPage <> dpOverview) then
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

function UptimeText(ASec: UInt64): string;
var
  Days, Hours, Mins: UInt64;
begin
  Days := ASec div 86400;
  Hours := (ASec div 3600) mod 24;
  Mins := (ASec div 60) mod 60;
  if Days > 0 then
    Result := Format(S('dash.uptime'), [Format(S('dash.uptime_dhm'), [Days, Hours, Mins])])
  else
    Result := Format(S('dash.uptime'), [Format(S('dash.uptime_hm'), [Hours, Mins])]);
end;

procedure TDashboardForm.HeaderPaint(Sender: TObject);
var
  Snap: TMetricsSnapshot;
  CumText: string;
begin
  Snap := Default(TMetricsSnapshot);
  if FPipeline <> nil then
    Snap := FPipeline.LastSnap;
  CumText := Format(S('dash.cum'), [FormatBytesGiB(Snap.DiskCumReadBytes),
    FormatBytesGiB(Snap.DiskCumWriteBytes), FormatBytesGiB(Snap.NetCumInBytes),
    FormatBytesGiB(Snap.NetCumOutBytes)]);
  DrawHudHeader(FHeaderPaint.Canvas, FHeaderPaint.ClientRect,
    'DISKLED HUD', S('dash.live'), ProductVersionText, UptimeText(Snap.UptimeSec),
    CumText, FLiveOn, HudPalette, CurrentMetrics);
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
    S('dash.power_remain_h'), S('dash.power_remain_m'), S('dash.power_remain_hm'),
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
  { A monitor may have been removed/rearranged while the window was hidden. }
  ClampIntoView;
  { Always open on the overview; FPage survives a caHide close. }
  SetPage(dpOverview);
  FUiTimer.Enabled := True;
  FMeterTimer.Enabled := True;
  RefreshData;
end;

procedure TDashboardForm.FormHide(Sender: TObject);
begin
  FUiTimer.Enabled := False;
  FMeterTimer.Enabled := False;
  HideProcTip;
  FProcPaused := False;
  if FProcess <> nil then
  begin
    FProcess.SetPaused(False);
    FProcess.SetActive(False);
  end;
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
