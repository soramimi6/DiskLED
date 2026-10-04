unit uMainForm;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Menus,
  Vcl.ExtCtrls,
  uLayoutTypes,
  uMetricsTypes,
  uAssetStore,
  uCollector,
  uDisplayPipeline,
  uHistoryBuffer,
  uDashboardHistory,
  uSettings,
  uHoverTip,
  uMeterRenderer,
  uDashboardForm,
  uWindowPlacement,
  uUpdateCheck;

const
  CMaxDriveTraySlots = 16;
  CTraySlotCount = 2 + CMaxDriveTraySlots;

type
  { One tray icon with its LED state. Slot 0 is the primary icon (always shown,
    falls back to the app icon); slot 1 is the net-only secondary icon, created
    on demand and hidden when its icons are unavailable. Slots 2.. are per
    logical drive, created while that drive is selected and present; DriveLetter
    is #0 when the slot is unused. Each slot has its own click-delay timer so one
    icon's pending single-click is never cancelled by another's double-click. }
  TTraySlot = record
    Icon: TTrayIcon;
    OffIcon: TIcon;
    OnIcon: TIcon;
    LedOn: Boolean;
    HasState: Boolean;
    ClickDelay: TTimer;
    AppIconFallback: Boolean;
    DriveLetter: Char;
  end;

  TMainForm = class(TForm)
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormShow(Sender: TObject);
    procedure FormActivate(Sender: TObject);
  private
    FAssets: TAssetStore;
    FLayout: TViewLayout;
    FLayoutCompact: TViewLayout;
    FLayoutFull: TViewLayout;
    FHasFull: Boolean;
    FBuffer: TBitmap;
    FPopup: TPopupMenu;
    FCollector: TMetricsCollector;
    FPipeline: TDisplayPipeline;
    FHistory: THistoryBuffer;
    FTimer: TTimer;
    FSettings: TAppSettings;
    FTraySlots: array[0..CTraySlotCount - 1] of TTraySlot;
    FDriveOffIcon: TIcon;
    FDriveOnIcon: TIcon;
    FAssetsRoot: string;
    FReadyToPersist: Boolean;
    FLastGraphTick: Cardinal;
    FHasGraphTick: Boolean;
    FGraphPeak: THistorySample;
    FGraphGen: Cardinal;
    FLastFp: TVisualFingerprint;
    FHasFp: Boolean;
    { Set once Render hits an unrecoverable asset error and starts shutting
      down; guards against showing the same error dialog again on every
      TimerTick before Application.Terminate actually stops the message loop. }
    FRenderFailed: Boolean;
    FMiCompact: TMenuItem;
    FMiFull: TMenuItem;
    FHoverTip: THoverTip;
    FHoverDelay: TTimer;
    FHoverArmed: Boolean;
    FDragging: Boolean;
    FGadgetDrag: TGadgetDragState;
    FVersionText: string;
    FHoverHeldText: string;
    FDriveHintTick: Cardinal;
    FHasDriveHint: Boolean;
    FHoverTextTick: Cardinal;
    FHasHoverText: Boolean;
    FMonitorDpi: Integer;
    FScale100: Integer;
    { Countdown of frame ticks over which the window is re-clamped into the
      work area after a DPI change: the taskbar resizes with the new scale and
      its work-area rect can still be stale on the tick the change is seen. }
    FDpiSettleTicks: Integer;
    FLastTopMostTick: Cardinal;
    FHasTopMostTick: Boolean;
    FDashboardHistory: TDashboardHistory;
    FDashboardPeak: TDashboardSample;
    FDashboardLastPushTick: Cardinal;
    FHasDashboardPushTick: Boolean;
    FDashboardForm: TDashboardForm;
    { Set around TOptionsForm.Execute's ShowModal call: that dialog is an
      owned, non-topmost window, so PollStayOnTop must not re-assert
      HWND_TOPMOST on the (disabled-while-modal) main form while it's up,
      or it would bury the dialog behind it. }
    FOptionsOpen: Boolean;
    FMiUpdate: TMenuItem;
    FUpdateDelay: TTimer;
    FUpdateGen: Integer;
    FClosing: Boolean;
    FActivateMsg: Cardinal;
    procedure BuildPopup;
    procedure ApplyMode(const AModeId: string);
    procedure ApplyViewSize;
    procedure ResetGraphPeak;
    procedure ResetDashboardPeak;
    procedure ApplyDpiScale;
    procedure PollMonitorDpiChange;
    procedure PollStayOnTop;
    function ResolveScale100: Integer;
    procedure ApplyDpiClientSize;
    procedure ShowDashboard;
    procedure ShowDashboardPage(APage: TDashboardPage);
    procedure ToggleCompactFull;
    procedure SetCompactView(ACompact: Boolean);
    procedure Render;
    procedure SyncModeChecks;
    procedure SyncViewMenu;
    function PrimarySourceIsDisk: Boolean;
    function BothLedSourcesOn: Boolean;
    function TrayLedSourceOn: Boolean;
    procedure TimerTick(Sender: TObject);
    procedure miModeClick(Sender: TObject);
    procedure miCompactClick(Sender: TObject);
    procedure miFullClick(Sender: TObject);
    procedure ApplyScaleChange;
    procedure SetWindowTrayState(AHidden, ALed: Boolean);
    procedure LeaveTrayOnly;
    procedure ReloadTrayIcons;
    procedure CreateTraySlot(AIndex: Integer);
    procedure EnsureTraySlot(AIndex: Integer);
    procedure HideTraySlot(AIndex: Integer);
    function TraySlotOf(ASender: TObject): Integer;
    function DriveSlotIndex(ALetter: Char): Integer;
    function FreeDriveSlotIndex: Integer;
    procedure ReleaseTraySlot(AIndex: Integer);
    procedure ReleaseDriveTrays;
    procedure SyncDriveTrays;
    procedure UpdateTrayLeds;
    procedure RefreshDriveHints;
    procedure UpdateTrayLed(AIndex: Integer; AOn: Boolean);
    procedure ResetTrayToAppIcon;
    procedure RefreshTrayIconForState;
    procedure miPingResultClick(Sender: TObject);
    procedure miOptionsClick(Sender: TObject);
    function CurrentDrivePresence: TDriveFlags;
    procedure miResetPositionClick(Sender: TObject);
    procedure miDashboardClick(Sender: TObject);
    procedure miUpdateClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure TrayDblClick(Sender: TObject);
    procedure TrayClick(Sender: TObject);
    procedure TrayClickDelayTick(Sender: TObject);
    procedure TrayBalloonClick(Sender: TObject);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMNCRButtonUp(var Message: TWMNCRButtonUp); message WM_NCRBUTTONUP;
    procedure WMContextMenu(var Message: TWMContextMenu); message WM_CONTEXTMENU;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
    procedure WMDpiChanged(var Message: TMessage); message WM_DPICHANGED;
    procedure WMDisplayChange(var Message: TMessage); message WM_DISPLAYCHANGE;
    procedure WMMoving(var Message: TMessage); message WM_MOVING;
    procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
    procedure WMEnterSizeMove(var Message: TMessage); message WM_ENTERSIZEMOVE;
    procedure WMNCLButtonDblClk(var Message: TWMNCLButtonDblClk); message WM_NCLBUTTONDBLCLK;
    procedure WMNCLButtonDown(var Message: TWMNCLButtonDown); message WM_NCLBUTTONDOWN;
    procedure WMNCMouseMove(var Message: TWMMouse); message WM_NCMOUSEMOVE;
    procedure WMNCMouseLeave(var Message: TMessage); message WM_NCMOUSELEAVE;
    procedure ShowAppPopup(AX, AY: Integer);
    procedure ApplyWindowBounds;
    procedure ApplySettingsToUi;
    procedure CaptureWindowPosToSettings;
    procedure PersistSettings;
    procedure ApplyStartupRegistration;
    procedure SetupTray;
    procedure BringWindowForward;
    procedure EnsureNoTaskbarButton;
    procedure DeleteTaskbarTab(AWnd: HWND);
    function MainIconPath: string;
    function UsingFullView: Boolean;
    function HoverInfoText: string;
    procedure ArmNcMouseLeave;
    procedure HideHoverTip;
    procedure HoverDelayTick(Sender: TObject);
    procedure RefreshHoverText;
    procedure SyncUpdateMenu;
    procedure ScheduleUpdateCheck;
    procedure CancelUpdateCheck;
    function UpdateCheckEnabled: Boolean;
    procedure UpdateDelayTick(Sender: TObject);
    procedure ApplyUpdateCheckResult(AGen: Integer; const AResult: TUpdateCheckResult);
    procedure OpenUpdatePage;
    procedure ShowUpdateBalloon(const AVersion: string);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure WndProc(var Message: TMessage); override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  Vcl.Dialogs,
  System.UITypes,
  System.Win.ComObj,
  Winapi.ShlObj,
  uAppStrings,
  uDisplayModes,
  uGraphRenderer,
  uOptionsForm,
  uStartup,
  uPackaging,
  uDpiScale,
  uTrayIconComposer,
  uSingleInstance,
  Winapi.CommCtrl,
  Winapi.ShellAPI;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { Unowned + APPWINDOW => taskbar. Owned tool window => no button.
    Params.X/Y are left at the inherited default (the control's current
    Left/Top): FormCreate restores the saved position into Left/Top before
    the first handle is ever created (see the comment there), so injecting
    FSettings.WindowX/Y here is unnecessary for that first creation and
    actively harmful for any later recreation (e.g. a FormStyle toggle in
    Options) — it would snap the window back to a possibly-stale saved
    position instead of wherever it currently is on screen. }
  Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
  Params.WndParent := Application.Handle;
  StrLCopy(Params.WinClassName, 'DiskLEDMainWnd', High(Params.WinClassName));
end;

procedure TMainForm.CreateWnd;
begin
  inherited CreateWnd;
  EnsureNoTaskbarButton;
  if FHoverTip <> nil then
    FHoverTip.SetOwner(Handle);
end;

procedure TMainForm.WndProc(var Message: TMessage);
begin
  { A second instance asks us to activate: same handling for a plain
    foreground request and for restoring out of tray size, since only this
    process's own logic knows which one applies right now. }
  if (FActivateMsg <> 0) and (Message.Msg = FActivateMsg) then
  begin
    if (FSettings <> nil) and FSettings.WindowHidden then
      LeaveTrayOnly
    else
      BringWindowForward;
    Message.Result := 0;
    Exit;
  end;
  inherited WndProc(Message);
end;

function TMainForm.MainIconPath: string;
begin
  Result := IncludeTrailingPathDelimiter(FAssetsRoot) + 'MAINICON.ico';
end;

procedure TMainForm.DeleteTaskbarTab(AWnd: HWND);
var
  Taskbar: ITaskbarList;
begin
  if AWnd = 0 then
    Exit;
  try
    Taskbar := CreateComObject(CLSID_TaskbarList) as ITaskbarList;
    Taskbar.HrInit;
    Taskbar.DeleteTab(AWnd);
  except
  end;
end;

procedure TMainForm.EnsureNoTaskbarButton;
var
  ExStyle: NativeInt;
begin
  { Application HWND owns the taskbar button when MainFormOnTaskbar=False.
    Clear APPWINDOW and hide it; also strip APPWINDOW from the main form. }
  ExStyle := GetWindowLong(Application.Handle, GWL_EXSTYLE);
  ExStyle := (ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
  SetWindowLong(Application.Handle, GWL_EXSTYLE, ExStyle);
  ShowWindow(Application.Handle, SW_HIDE);
  DeleteTaskbarTab(Application.Handle);

  if HandleAllocated then
  begin
    ExStyle := GetWindowLong(Handle, GWL_EXSTYLE);
    ExStyle := (ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
    SetWindowLong(Handle, GWL_EXSTYLE, ExStyle);
    DeleteTaskbarTab(Handle);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  DoubleBuffered := True;
  Scaled := False;
  FReadyToPersist := False;
  FClosing := False;
  FUpdateGen := 0;
  FActivateMsg := TSingleInstance.ActivateMsg;
  { poDesigned: do not let VCL recenter and wipe restored Left/Top. }
  Position := poDesigned;
  { dmDesktop: DefaultMonitor otherwise defaults to dmActiveForm, and
    TCustomForm.SetVisible calls SetWindowToMonitor on the first Show
    (from Application.Run). If some other form (e.g. the dashboard, opened
    earlier in this same FormCreate via ShowDashboard) is on a different
    monitor, SetWindowToMonitor force-relocates this window onto that
    monitor regardless of Position — poDesigned does not guard against it. }
  DefaultMonitor := dmDesktop;

  FSettings := TAppSettings.Create;
  FSettings.Load;
  { Store build: FSettings.Startup is not read for the Options checkbox
    (TOptionsForm.LoadFromSettings reads TStartup.QueryState directly) and
    ApplyStartupRegistration below skips Store builds entirely -- so there is
    nothing to sync here, and a WinRT round-trip this early (before
    Application.Run's message loop even starts) could stall launch. }
  if not IsStorePackage then
    FSettings.Startup := TStartup.IsRegistered;

  { Starting with the window hidden: Application.Run otherwise force-shows
    the main form right after this method returns (FMainForm.Visible := True
    when ShowMainForm), regardless of the Visible this method leaves behind. }
  if FSettings.WindowHidden then
    Application.ShowMainForm := False;

  try
    FAssetsRoot := TAssetStore.LocateRoot;
    LoadDisplayModes(FAssetsRoot);
    FAssets := TAssetStore.Create(FAssetsRoot);
  except
    on E: Exception do
    begin
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Application.Terminate;
      Exit;
    end;
  end;

  { Tray uses MAINICON; do not assign Application.Icon (feeds taskbar button). }
  if FileExists(MainIconPath) then
  try
    Icon.LoadFromFile(MainIconPath);
  except
  end;

  FBuffer := TBitmap.Create;
  FBuffer.PixelFormat := pf24bit;
  FCollector := TMetricsCollector.Create;
  FPipeline := TDisplayPipeline.Create;
  FHistory := THistoryBuffer.Create(60);
  FDashboardHistory := TDashboardHistory.Create(300);
  FHasGraphTick := False;
  FHasDashboardPushTick := False;
  FMonitorDpi := 96;
  FScale100 := 100;
  FDpiSettleTicks := 0;
  FHasTopMostTick := False;
  ResetGraphPeak;
  ResetDashboardPeak;
  FTimer := TTimer.Create(Self);
  FTimer.OnTimer := TimerTick;

  BuildPopup;
  PopupMenu := FPopup;
  SetupTray;
  EnsureNoTaskbarButton;

  { Restore the saved position before ApplySettingsToUi: its FormStyle
    assignment can recreate the window handle (see the comment there), and
    ApplyMode's own "keep position" step reads the current Left/Top too. If
    either ran first, the real window would be created/moved using the
    form's design-time default (100, 100) — which sits on the primary
    monitor — instead of the restored (possibly secondary) monitor. }
  SetBounds(FSettings.WindowX, FSettings.WindowY, Width, Height);
  ApplySettingsToUi;
  ApplyMode(FSettings.Mode);
  ApplyWindowBounds;
  CaptureWindowPosToSettings;
  FReadyToPersist := True;
  { Write back clamped position so next launch matches what user sees. }
  PersistSettings;

  ApplyDpiScale;

  FCollector.RequestPing;
  EnsureNoTaskbarButton;

  FVersionText := GetProductVersionText;
  FHoverTip := THoverTip.Create;
  FHoverTip.SetOwner(Handle);
  FHoverDelay := TTimer.Create(Self);
  FHoverDelay.Enabled := False;
  FHoverDelay.OnTimer := HoverDelayTick;
  if Application.HintPause > 0 then
    FHoverDelay.Interval := Application.HintPause
  else
    FHoverDelay.Interval := 500;
  RefreshHoverText;

  if (FSettings <> nil) and FSettings.DashboardOpen then
    ShowDashboard;

  FUpdateDelay := TTimer.Create(Self);
  FUpdateDelay.Enabled := False;
  FUpdateDelay.Interval := 5000;
  FUpdateDelay.OnTimer := UpdateDelayTick;

  { Menu item starts hidden (BuildPopup's default) and stays that way until
    this session's own check confirms a newer version via
    ApplyUpdateCheckResult -> SyncUpdateMenu. Do not call SyncUpdateMenu here:
    it would show the item immediately based on last session's persisted
    UpdateLatestKnown, which can be stale (an old GitHub check result, or a
    leftover from an earlier debug run) until this session's check overwrites
    it a few seconds later. }
  if UpdateCheckEnabled then
    ScheduleUpdateCheck;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  EnsureNoTaskbarButton;
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  EnsureNoTaskbarButton;
end;

procedure TMainForm.SetupTray;
begin
  { Notification area only — not a hide-to-tray feature. Taskbar button stays off via WS_EX_TOOLWINDOW. }
  CreateTraySlot(0);
  FTraySlots[0].Icon.OnBalloonClick := TrayBalloonClick;
  ResetTrayToAppIcon;
  FTraySlots[0].Icon.Visible := True;
end;

procedure TMainForm.CreateTraySlot(AIndex: Integer);
begin
  FTraySlots[AIndex].AppIconFallback := AIndex = 0;
  FTraySlots[AIndex].Icon := TTrayIcon.Create(Self);
  FTraySlots[AIndex].Icon.Hint := 'DiskLED';
  FTraySlots[AIndex].Icon.PopupMenu := FPopup;
  FTraySlots[AIndex].Icon.OnDblClick := TrayDblClick;
  FTraySlots[AIndex].Icon.OnClick := TrayClick;
  FTraySlots[AIndex].ClickDelay := TTimer.Create(Self);
  FTraySlots[AIndex].ClickDelay.Enabled := False;
  FTraySlots[AIndex].ClickDelay.Interval := GetDoubleClickTime;
  FTraySlots[AIndex].ClickDelay.OnTimer := TrayClickDelayTick;
end;

procedure TMainForm.BringWindowForward;
begin
  Show;
  SetForegroundWindow(Handle);
  EnsureNoTaskbarButton;
  ApplyWindowBounds;
end;

procedure TMainForm.ApplySettingsToUi;
begin
  if FSettings.StayOnTop then
    FormStyle := fsStayOnTop
  else
    FormStyle := fsNormal;
  { FormStyle change recreates the HWND — re-assert no taskbar button. }
  EnsureNoTaskbarButton;

  if FSettings.Fps < 1 then
    FSettings.Fps := 15;
  FTimer.Interval := Round(1000.0 / FSettings.Fps);
  FTimer.Enabled := True;

  { First call is during FormCreate (FReadyToPersist=False): apply scale only.
    Clearing/redrawing with an empty layout raises and aborts FormCreate, then
    the already-enabled timer floods error dialogs. }
  if (FPipeline <> nil) and FPipeline.ApplySpeedScale(FSettings.SpeedScale) and
    FReadyToPersist then
  begin
    if FHistory <> nil then
      FHistory.Clear;
    if FDashboardHistory <> nil then
      FDashboardHistory.ClearLanes([dlNetIn, dlNetOut]);
    ResetGraphPeak;
    Inc(FGraphGen);
    FHasFp := False;
    Render;
    Invalidate;
  end;

  FCollector.ApplyPingSettings(
    FSettings.PingEnabled,
    FSettings.PingIntervalSec,
    FSettings.PingHost,
    FSettings.PingAutoGateway,
    FSettings.PingFairMs,
    FSettings.PingSlowMs,
    FSettings.PingTimeoutMs);
end;

procedure TMainForm.CaptureWindowPosToSettings;
begin
  if FSettings = nil then
    Exit;
  FSettings.WindowX := Left;
  FSettings.WindowY := Top;
end;

procedure TMainForm.PersistSettings;
begin
  if (FSettings = nil) or (not FReadyToPersist) then
    Exit;
  CaptureWindowPosToSettings;
  if FLayout.ModeId <> '' then
    FSettings.Mode := FLayout.ModeId;
  if FDashboardForm <> nil then
    FDashboardForm.PersistDashboardDip;
  try
    FSettings.Save;
  except
  end;
end;

procedure TMainForm.ApplyStartupRegistration;
begin
  if (FSettings = nil) or (not FReadyToPersist) then
    Exit;
  { Store build: the startup task is managed by package identity, not by exe
    path, so there is nothing to re-sync at exit — and a WinRT round-trip here
    would pump the message loop mid-teardown. The Options dialog already applied
    any change. }
  if IsStorePackage then
    Exit;
  try
    { Non-packaged: re-assert the Run key so a moved/updated exe path follows.
      IsRegistered only checks whether the value exists, not whether its path
      still matches ParamStr(0) -- comparing it against FSettings.Startup would
      never write once startup is enabled, silently breaking the path
      self-heal. Skip only when there is definitely nothing to do (startup
      off and no stale key present); otherwise always re-write. }
    if FSettings.Startup or TStartup.IsRegistered then
      TStartup.SetRegistered(FSettings.Startup);
  except
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  FClosing := True;
  Inc(FUpdateGen);
  if FUpdateDelay <> nil then
    FUpdateDelay.Enabled := False;
  if FHoverDelay <> nil then
    FHoverDelay.Enabled := False;
  HideHoverTip;
  FreeAndNil(FHoverTip);
  if FTimer <> nil then
    FTimer.Enabled := False;
  FreeAndNil(FDashboardForm);
  FreeAndNil(FTraySlots[0].OffIcon);
  FreeAndNil(FTraySlots[0].OnIcon);
  FreeAndNil(FTraySlots[1].OffIcon);
  FreeAndNil(FTraySlots[1].OnIcon);
  FreeAndNil(FDriveOffIcon);
  FreeAndNil(FDriveOnIcon);
  FCollector.Free;
  FPipeline.Free;
  FHistory.Free;
  FDashboardHistory.Free;
  FBuffer.Free;
  FAssets.Free;
  FSettings.Free;
  FSettings := nil;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  { Capture while the window still has a valid position. }
  PersistSettings;
  ApplyStartupRegistration;
  CanClose := True;
end;

procedure TMainForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  PersistSettings;
  ApplyStartupRegistration;
end;

procedure TMainForm.BuildPopup;
var
  i: Integer;
  Def: TDisplayModeDef;
  miMode: TMenuItem;
  Sep: TMenuItem;
  miPingResult: TMenuItem;
  miOpt: TMenuItem;
  miResetPosition: TMenuItem;
  miExit: TMenuItem;
begin
  FPopup := TPopupMenu.Create(Self);

  for i := 0 to DisplayModeCount - 1 do
  begin
    Def := DisplayModeByIndex(i);
    miMode := TMenuItem.Create(FPopup);
    miMode.Caption := Def.Caption;
    miMode.Hint := Def.Id;
    miMode.RadioItem := True;
    miMode.GroupIndex := 1;
    miMode.Tag := i;
    miMode.OnClick := miModeClick;
    FPopup.Items.Add(miMode);
  end;

  Sep := TMenuItem.Create(FPopup);
  Sep.Caption := '-';
  FPopup.Items.Add(Sep);

  FMiCompact := TMenuItem.Create(FPopup);
  FMiCompact.Caption := S('menu.compact');
  FMiCompact.RadioItem := True;
  FMiCompact.GroupIndex := 2;
  FMiCompact.OnClick := miCompactClick;
  FPopup.Items.Add(FMiCompact);

  FMiFull := TMenuItem.Create(FPopup);
  FMiFull.Caption := S('menu.full');
  FMiFull.RadioItem := True;
  FMiFull.GroupIndex := 2;
  FMiFull.OnClick := miFullClick;
  FPopup.Items.Add(FMiFull);

  Sep := TMenuItem.Create(FPopup);
  Sep.Caption := '-';
  FPopup.Items.Add(Sep);

  miResetPosition := TMenuItem.Create(FPopup);
  miResetPosition.Caption := S('menu.reset_position');
  miResetPosition.OnClick := miResetPositionClick;
  FPopup.Items.Add(miResetPosition);

  miOpt := TMenuItem.Create(FPopup);
  miOpt.Caption := S('menu.dashboard');
  miOpt.OnClick := miDashboardClick;
  FPopup.Items.Add(miOpt);

  miPingResult := TMenuItem.Create(FPopup);
  miPingResult.Caption := S('menu.ping_result');
  miPingResult.OnClick := miPingResultClick;
  FPopup.Items.Add(miPingResult);

  miOpt := TMenuItem.Create(FPopup);
  miOpt.Caption := S('menu.options');
  miOpt.OnClick := miOptionsClick;
  FPopup.Items.Add(miOpt);

  Sep := TMenuItem.Create(FPopup);
  Sep.Caption := '-';
  FPopup.Items.Add(Sep);

  FMiUpdate := TMenuItem.Create(FPopup);
  FMiUpdate.Caption := S('menu.update');
  FMiUpdate.Visible := False;
  FMiUpdate.OnClick := miUpdateClick;
  FPopup.Items.Add(FMiUpdate);

  miExit := TMenuItem.Create(FPopup);
  miExit.Caption := S('menu.exit');
  miExit.OnClick := miExitClick;
  FPopup.Items.Add(miExit);
end;

procedure TMainForm.ApplyMode(const AModeId: string);
var
  Def: TDisplayModeDef;
  KeepLeft, KeepTop: Integer;
  W: Integer;
begin
  KeepLeft := Left;
  KeepTop := Top;

  Def := DisplayModeById(AModeId);
  FLayoutCompact := Def.Layout;
  FHasFull := Def.HasFull;
  FLayoutFull := Def.FullLayout;
  if FHasFull and FLayoutFull.Graph.Enabled then
  begin
    W := GraphMaxWidth(FLayoutFull.Graph);
    if W < 1 then
      W := 1;
    FHistory.SetCapacity(W);
    ResetGraphPeak;
  end;

  if (FSettings <> nil) and (not FSettings.Compact) and (not FHasFull) then
    FSettings.Compact := True;

  ApplyViewSize;

  { Keep screen position when switching modes (size changes). }
  SetBounds(KeepLeft, KeepTop, Width, Height);
  ApplyWindowBounds;

  if FSettings <> nil then
    FSettings.Mode := FLayout.ModeId;

  SyncModeChecks;
  Render;
  Invalidate;
  FHasFp := False;
  PersistSettings;
  RefreshTrayIconForState;
end;

function TMainForm.UsingFullView: Boolean;
begin
  Result := FHasFull and (FSettings <> nil) and (not FSettings.Compact);
end;

procedure TMainForm.ResetGraphPeak;
begin
  FGraphPeak := ZeroHistorySample;
end;

procedure TMainForm.ResetDashboardPeak;
begin
  FDashboardPeak := ZeroDashboardSample;
end;

procedure TMainForm.ApplyDpiScale;
begin
  if HandleAllocated then
    FMonitorDpi := MonitorDpiForWindow(Handle)
  else
    FMonitorDpi := MonitorDpiForWindow(0);
  FScale100 := ResolveScale100;
  ApplyDpiClientSize;
end;

procedure TMainForm.PollMonitorDpiChange;
var
  Dpi: Integer;
begin
  { WM_DPICHANGED is not reliably delivered to this owned tool window when the
    scale of the monitor it already sits on is changed in Settings (a move to
    another monitor does deliver it). Poll from the frame timer so a stationary
    gadget still resizes promptly, like an ordinary window. }
  if FDragging or FClosing or (not HandleAllocated) then
    Exit;
  Dpi := MonitorEffectiveDpiForWindow(Handle);
  if (Dpi >= 1) and (Dpi <> FMonitorDpi) then
  begin
    FMonitorDpi := Dpi;
    FScale100 := ResolveScale100;
    ApplyDpiClientSize;
    ApplyWindowBounds;
    RefreshTrayIconForState;
    FHasFp := False;
    Render;
    Invalidate;
    { Keep re-clamping for ~2 s: the work area the clamp above used can still
      hold the pre-scale taskbar height on this first tick. }
    FDpiSettleTicks := 30;
  end
  else if FDpiSettleTicks > 0 then
  begin
    Dec(FDpiSettleTicks);
    ApplyWindowBounds;
  end;
end;

procedure TMainForm.PollStayOnTop;
const
  ReassertIntervalMs = 2000;
var
  NowTick: Cardinal;
  Gti: TGUIThreadInfo;
begin
  { FormStyle=fsStayOnTop (see ApplySettingsToUi) only asserts WS_EX_TOPMOST
    once, on assignment. Windows can still push this window out of the
    topmost z-order band later (observed behind browser windows) with no
    reliable notification back to us, so periodically re-assert its place at
    the top of that band -- cheap compared to the FormStyle path, which
    recreates the HWND. }
  if (FSettings = nil) or (not FSettings.StayOnTop) or FDragging or
    FClosing or (not HandleAllocated) then
    Exit;
  { Options/Dashboard are owned windows that never set FormStyle themselves.
    Re-asserting HWND_TOPMOST on the main form while one of them is open
    would bury it behind the (possibly disabled) main form, since SetWindowPos
    doesn't re-elevate an already-open owned window for us. }
  if FOptionsOpen or ((FDashboardForm <> nil) and FDashboardForm.Visible) then
    Exit;
  { A right-click / tray menu is a TrackPopupMenu modal loop that still
    dispatches WM_TIMER, so this poll keeps running while it is open. The menu
    window sits in the same topmost band, and re-asserting HWND_TOPMOST here
    would raise the gadget above it. GUI_INMENUMODE covers every menu on this
    thread (gadget, tray, dashboard) without tracking open/close ourselves;
    the next tick after it closes re-asserts as usual. }
  Gti.cbSize := SizeOf(Gti);
  if GetGUIThreadInfo(GetCurrentThreadId, Gti) and
    ((Gti.flags and (GUI_INMENUMODE or GUI_POPUPMENUMODE)) <> 0) then
    Exit;
  NowTick := GetTickCount;
  if FHasTopMostTick and (NowTick - FLastTopMostTick < ReassertIntervalMs) then
    Exit;
  FLastTopMostTick := NowTick;
  FHasTopMostTick := True;
  SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

function TMainForm.ResolveScale100: Integer;
begin
  { Scale = 0 means "automatic" (derive from monitor DPI). A pinned 100/150/200
    wins regardless of DPI, so a fixed gadget stays that size across monitors. }
  if (FSettings <> nil) and (FSettings.Scale >= 100) then
    Result := FSettings.Scale
  else
    Result := GadgetScale100(FMonitorDpi);
end;

procedure TMainForm.ApplyDpiClientSize;
var
  CW, CH: Integer;
begin
  if FLayout.Width < 1 then
    Exit;
  LayoutClientSize(FLayout.Width, FLayout.Height, FScale100, CW, CH);
  ClientWidth := CW;
  ClientHeight := CH;
end;

procedure TMainForm.ShowDashboard;
begin
  if FDashboardForm = nil then
    FDashboardForm := TDashboardForm.Create(Self, FPipeline, FDashboardHistory,
      FCollector, FSettings);
  if FSettings <> nil then
    FSettings.DashboardOpen := True;
  FDashboardForm.Show;
end;

procedure TMainForm.ShowDashboardPage(APage: TDashboardPage);
begin
  if FDashboardForm = nil then
    FDashboardForm := TDashboardForm.Create(Self, FPipeline, FDashboardHistory,
      FCollector, FSettings);
  if FSettings <> nil then
    FSettings.DashboardOpen := True;
  FDashboardForm.ShowPage(APage);
end;

procedure TMainForm.ApplyViewSize;
begin
  if UsingFullView then
    FLayout := FLayoutFull
  else
    FLayout := FLayoutCompact;

  Color := FLayout.MaskColor;
  TransparentColor := FLayout.Transparent;
  TransparentColorValue := FLayout.MaskColor;
  ClientWidth := FLayout.Width;
  ClientHeight := FLayout.Height;
  if FPipeline <> nil then
    FPipeline.ApplyBallistics(BuildMeterBallistics(FLayout));
  ApplyDpiClientSize;
end;

procedure TMainForm.ToggleCompactFull;
begin
  if (FSettings = nil) or (not FHasFull) then
    Exit;
  SetCompactView(not FSettings.Compact);
end;

procedure TMainForm.SetCompactView(ACompact: Boolean);
var
  KeepLeft, KeepTop: Integer;
begin
  if FSettings = nil then
    Exit;
  if (not ACompact) and (not FHasFull) then
    ACompact := True;
  if FSettings.Compact = ACompact then
  begin
    SyncViewMenu;
    Exit;
  end;
  KeepLeft := Left;
  KeepTop := Top;
  FSettings.Compact := ACompact;
  ApplyViewSize;
  SetBounds(KeepLeft, KeepTop, Width, Height);
  ApplyWindowBounds;
  PersistSettings;
  SyncViewMenu;
  Render;
  Invalidate;
  FHasFp := False;
end;

procedure TMainForm.ApplyWindowBounds;
var
  R: TRect;
begin
  R := BoundsRect;
  ConstrainAndSnapRect(R, FMonitorDpi);
  if not EqualRect(R, BoundsRect) then
    BoundsRect := R;
end;

procedure TMainForm.SyncModeChecks;
var
  i: Integer;
  mi: TMenuItem;
begin
  if FPopup = nil then
    Exit;
  for i := 0 to FPopup.Items.Count - 1 do
  begin
    mi := FPopup.Items[i];
    if mi.RadioItem and (mi.GroupIndex = 1) then
      mi.Checked := SameText(mi.Hint, FLayout.ModeId);
  end;
  SyncViewMenu;
end;

procedure TMainForm.SyncViewMenu;
var
  InFull: Boolean;
begin
  if (FMiCompact = nil) or (FMiFull = nil) then
    Exit;
  { Compact layout always exists; Full only when [ModeFull] is defined.
    Size is independent of window/tray visibility, so it reflects the saved
    preference regardless of Hidden/Led. }
  FMiCompact.Enabled := True;
  FMiFull.Enabled := FHasFull;
  InFull := UsingFullView;
  FMiCompact.Checked := not InFull;
  FMiFull.Checked := InFull;
end;

procedure TMainForm.Render;
begin
  if FRenderFailed then
    Exit;
  if (FAssets = nil) or (FBuffer = nil) then
    Exit;
  if (FLayout.Width < 1) or (FLayout.Height < 1) or (FLayout.BgFile = '') then
    Exit;
  try
    { Loads the mode's image assets (background, meters, digit font) on first
      use; a missing/corrupt file raises here. This is the single choke point
      for all four call sites (FormCreate's initial ApplyMode, ApplyMode
      itself, the compact/full toggle, and every TimerTick while the
      fingerprint changes) -- guarding it here instead of at one caller covers
      all of them, including the periodic TimerTick call that would otherwise
      keep re-raising the same error after a failed mode switch. }
    FBuffer.SetSize(FLayout.Width, FLayout.Height);
    TMeterRenderer.DrawBackground(FBuffer.Canvas, FLayout, FAssets);
    if FPipeline <> nil then
      TMeterRenderer.DrawMeters(FBuffer.Canvas, FLayout, FAssets, FPipeline.State);
    if UsingFullView and (FHistory <> nil) and FLayout.Graph.Enabled then
      TGraphRenderer.Draw(FBuffer.Canvas, FLayout.Graph, FHistory);
  except
    on E: Exception do
    begin
      FRenderFailed := True;
      MessageDlg(E.Message, mtError, [mbOK], 0);
      Application.Terminate;
    end;
  end;
end;

procedure TMainForm.TimerTick(Sender: TObject);
var
  IntervalMs: Cardinal;
  NowTick: Cardinal;
  Sample: THistorySample;
  DashSample: TDashboardSample;
  GraphKey: Cardinal;
  Fp: TVisualFingerprint;
begin
  if (FCollector = nil) or (FPipeline = nil) then
    Exit;
  PollMonitorDpiChange;
  PollStayOnTop;
  FCollector.TickPing;
  FPipeline.Update(FCollector.Collect);

  if (FHistory <> nil) and (FSettings <> nil) then
  begin
    Sample.Cpu := FPipeline.Normalized.Cpu;
    Sample.Mem := FPipeline.Normalized.Mem;
    Sample.Swap := FPipeline.Normalized.Swap;
    Sample.DiskRead := FPipeline.Normalized.DiskRead;
    Sample.DiskWrite := FPipeline.Normalized.DiskWrite;
    Sample.NetIn := FPipeline.Normalized.NetIn;
    Sample.NetOut := FPipeline.Normalized.NetOut;
    AccruePeak(FGraphPeak, Sample);

    if FSettings.GraphRateHz <= 0 then
      IntervalMs := 1000
    else
      IntervalMs := Cardinal(Round(1000.0 / FSettings.GraphRateHz));
    NowTick := GetTickCount;
    if (not FHasGraphTick) or ((NowTick - FLastGraphTick) >= IntervalMs) then
    begin
      FHistory.Push(FGraphPeak);
      ResetGraphPeak;
      FLastGraphTick := NowTick;
      FHasGraphTick := True;
      Inc(FGraphGen);
    end;
  end;

  if FDashboardHistory <> nil then
  begin
    DashSample.Cpu := FPipeline.Normalized.Cpu;
    DashSample.Gpu := FPipeline.Normalized.Gpu;
    DashSample.Mem := FPipeline.Normalized.Mem;
    DashSample.Swap := FPipeline.Normalized.Swap;
    DashSample.DiskRead := FPipeline.Normalized.DiskRead;
    DashSample.DiskWrite := FPipeline.Normalized.DiskWrite;
    DashSample.NetIn := FPipeline.Normalized.NetIn;
    DashSample.NetOut := FPipeline.Normalized.NetOut;
    AccrueDashboardPeak(FDashboardPeak, DashSample);
    NowTick := GetTickCount;
    if (not FHasDashboardPushTick) or
      ((NowTick - FDashboardLastPushTick) >= 1000) then
    begin
      FDashboardHistory.Push(FDashboardPeak);
      ResetDashboardPeak;
      FDashboardLastPushTick := NowTick;
      FHasDashboardPushTick := True;
    end;
  end;

  { Window rendering and the tray LED(s) are independent now: either, both,
    or (checked at the settings layer) neither can be active at once. }
  if (FSettings <> nil) and FSettings.TrayLed then
    UpdateTrayLeds;
  if (FSettings = nil) or (not FSettings.WindowHidden) then
  begin
    if UsingFullView then
      GraphKey := FGraphGen
    else
      GraphKey := 0;
    Fp := TMeterRenderer.Fingerprint(FLayout, FPipeline.State, GraphKey);
    if (not FHasFp) or (not TMeterRenderer.SameFingerprint(Fp, FLastFp)) then
    begin
      Render;
      Invalidate;
      FLastFp := Fp;
      FHasFp := True;
    end;
  end;
  RefreshHoverText;
end;

procedure TMainForm.FormPaint(Sender: TObject);
var
  DestW, DestH: Integer;
begin
  if FBuffer = nil then
    Exit;
  DestW := MulDiv(FLayout.Width, FScale100, 100);
  DestH := MulDiv(FLayout.Height, FScale100, 100);
  if (DestW < 1) or (DestH < 1) then
    Exit;
  SetStretchBltMode(Canvas.Handle, COLORONCOLOR);
  StretchBlt(Canvas.Handle, 0, 0, DestW, DestH, FBuffer.Canvas.Handle, 0, 0,
    FLayout.Width, FLayout.Height, SRCCOPY);
end;

procedure TMainForm.miModeClick(Sender: TObject);
begin
  ApplyMode(TMenuItem(Sender).Hint);
end;

procedure TMainForm.miCompactClick(Sender: TObject);
begin
  { SetCompactView leaves tray size itself when it's active. }
  SetCompactView(True);
end;

procedure TMainForm.miFullClick(Sender: TObject);
begin
  SetCompactView(False);
end;

procedure TMainForm.ApplyScaleChange;
var
  KeepLeft, KeepTop: Integer;
begin
  KeepLeft := Left;
  KeepTop := Top;
  ApplyDpiScale;
  SetBounds(KeepLeft, KeepTop, Width, Height);
  ApplyWindowBounds;
  FHasFp := False;
  Render;
  Invalidate;
end;

function TMainForm.PrimarySourceIsDisk: Boolean;
begin
  { Disk is the primary (slot 0) source whenever it's on at all -- including
    when both are on, in which case net becomes the secondary (slot 1). Net is
    primary only when it's the sole source selected. }
  Result := (FSettings = nil) or FSettings.TrayLedDisk;
end;

function TMainForm.BothLedSourcesOn: Boolean;
begin
  Result := (FSettings <> nil) and FSettings.TrayLedDisk and FSettings.TrayLedNet;
end;

function TMainForm.TrayLedSourceOn: Boolean;
begin
  Result := False;
  if (FSettings = nil) or (FPipeline = nil) then
    Exit;
  if PrimarySourceIsDisk then
    Result := FPipeline.State.DiskRWOn
  else
    Result := FPipeline.State.NetActivityOn;
end;

procedure TMainForm.ReloadTrayIcons;
var
  DiskDir, NetDir, PrimaryDir, PrimarySrc: string;
begin
  FreeAndNil(FTraySlots[0].OffIcon);
  FreeAndNil(FTraySlots[0].OnIcon);
  FreeAndNil(FTraySlots[1].OffIcon);
  FreeAndNil(FTraySlots[1].OnIcon);
  FreeAndNil(FDriveOffIcon);
  FreeAndNil(FDriveOnIcon);
  if FSettings = nil then
    Exit;
  { Skin-independent: assets/tray/<type>/<source>Off|On.ico, unrelated to the
    gadget's current display mode. }
  { Disk and network each have their own color (TrayLedType /
    TrayLedTypeNet). }
  DiskDir := 'tray' + PathDelim + FSettings.TrayLedType;
  NetDir := 'tray' + PathDelim + FSettings.TrayLedTypeNet;
  if PrimarySourceIsDisk then
  begin
    PrimaryDir := DiskDir;
    PrimarySrc := 'disk';
  end
  else
  begin
    PrimaryDir := NetDir;
    PrimarySrc := 'net';
  end;
  FTraySlots[0].OffIcon := TAssetStore.LoadIconFile(
    TAssetStore.BuildPath(FAssetsRoot, PrimaryDir, PrimarySrc + 'Off.ico'), LIM_SMALL);
  FTraySlots[0].OnIcon := TAssetStore.LoadIconFile(
    TAssetStore.BuildPath(FAssetsRoot, PrimaryDir, PrimarySrc + 'On.ico'), LIM_SMALL);
  if BothLedSourcesOn then
  begin
    FTraySlots[1].OffIcon := TAssetStore.LoadIconFile(
      TAssetStore.BuildPath(FAssetsRoot, NetDir, 'netOff.ico'), LIM_SMALL);
    FTraySlots[1].OnIcon := TAssetStore.LoadIconFile(
      TAssetStore.BuildPath(FAssetsRoot, NetDir, 'netOn.ico'), LIM_SMALL);
  end;
  FDriveOffIcon := TAssetStore.LoadIconFile(
    TAssetStore.BuildPath(FAssetsRoot, DiskDir, 'diskOff.ico'), LIM_SMALL);
  FDriveOnIcon := TAssetStore.LoadIconFile(
    TAssetStore.BuildPath(FAssetsRoot, DiskDir, 'diskOn.ico'), LIM_SMALL);
end;

procedure TMainForm.ResetTrayToAppIcon;
var
  AppIcon: TIcon;
begin
  if FTraySlots[0].Icon = nil then
    Exit;
  FTraySlots[0].HasState := False;
  AppIcon := TIcon.Create;
  try
    if FileExists(MainIconPath) then
    try
      AppIcon.LoadFromFile(MainIconPath);
    except
    end;
    if AppIcon.Empty then
    try
      AppIcon.Assign(Icon);
    except
    end;
    { Assigning the whole property (not touching the icon in place) is
      what makes TCustomTrayIcon.SetIcon sync FCurrentIcon and call
      Refresh; loading into the returned TIcon directly leaves the live
      tray icon (FCurrentIcon) stale until something else happens to
      refresh it. }
    FTraySlots[0].Icon.Icon := AppIcon;
  finally
    AppIcon.Free;
  end;
end;

procedure TMainForm.UpdateTrayLed(AIndex: Integer; AOn: Boolean);
var
  Src: TIcon;
begin
  if (FTraySlots[AIndex].Icon = nil) or (not FTraySlots[AIndex].Icon.Visible) then
    Exit;
  if FTraySlots[AIndex].HasState and (FTraySlots[AIndex].LedOn = AOn) then
    Exit;
  if AOn then
    Src := FTraySlots[AIndex].OnIcon
  else
    Src := FTraySlots[AIndex].OffIcon;
  if (Src <> nil) and (not Src.Empty) then
    FTraySlots[AIndex].Icon.Icon := Src
  else if FTraySlots[AIndex].AppIconFallback then
    { [Tray] missing or icon failed to load: fall back to the fixed app icon
      instead of leaving a stale or blank tray icon. }
    ResetTrayToAppIcon
  else
  begin
    { No app-icon fallback for a secondary icon: hide it rather than leave a
      blank/default icon parked in the tray. HideTraySlot leaves the slot in
      the not-shown state, so this failed attempt is not recorded as applied. }
    HideTraySlot(AIndex);
    Exit;
  end;
  FTraySlots[AIndex].LedOn := AOn;
  FTraySlots[AIndex].HasState := True;
end;

procedure TMainForm.EnsureTraySlot(AIndex: Integer);
begin
  if FTraySlots[AIndex].Icon = nil then
  begin
    CreateTraySlot(AIndex);
    if AIndex = 1 then
      FTraySlots[AIndex].Icon.Hint := S('tray.hint_net');
  end;
  FTraySlots[AIndex].Icon.Visible := True;
end;

procedure TMainForm.HideTraySlot(AIndex: Integer);
begin
  if FTraySlots[AIndex].Icon <> nil then
    FTraySlots[AIndex].Icon.Visible := False;
  FTraySlots[AIndex].HasState := False;
end;

function TMainForm.TraySlotOf(ASender: TObject): Integer;
var
  I: Integer;
begin
  for I := 0 to High(FTraySlots) do
    if (ASender = FTraySlots[I].Icon) or (ASender = FTraySlots[I].ClickDelay) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

function TMainForm.DriveSlotIndex(ALetter: Char): Integer;
var
  I: Integer;
begin
  for I := 2 to High(FTraySlots) do
    if FTraySlots[I].DriveLetter = ALetter then
      Exit(I);
  Result := -1;
end;

function TMainForm.FreeDriveSlotIndex: Integer;
var
  I: Integer;
begin
  for I := 2 to High(FTraySlots) do
    if FTraySlots[I].DriveLetter = #0 then
      Exit(I);
  Result := -1;
end;

procedure TMainForm.ReleaseTraySlot(AIndex: Integer);
begin
  FreeAndNil(FTraySlots[AIndex].Icon);
  FreeAndNil(FTraySlots[AIndex].OffIcon);
  FreeAndNil(FTraySlots[AIndex].OnIcon);
  FreeAndNil(FTraySlots[AIndex].ClickDelay);
  FTraySlots[AIndex].OffIcon := nil;
  FTraySlots[AIndex].OnIcon := nil;
  FTraySlots[AIndex].LedOn := False;
  FTraySlots[AIndex].HasState := False;
  FTraySlots[AIndex].DriveLetter := #0;
end;

procedure TMainForm.ReleaseDriveTrays;
var
  I: Integer;
begin
  for I := 2 to High(FTraySlots) do
    if FTraySlots[I].DriveLetter <> #0 then
      ReleaseTraySlot(I);
end;

{ Creates a tray icon for each selected drive that PDH reports as present and
  removes the ones whose drive is no longer wanted. Slots are capped at
  CMaxDriveTraySlots; drives beyond the cap are not shown. }
procedure TMainForm.SyncDriveTrays;
var
  Letter: TDriveLetter;
  I, Idx: Integer;
  Wanted: TDriveFlags;
begin
  for Letter := Low(TDriveLetter) to High(TDriveLetter) do
    Wanted[Letter] := FSettings.TrayLedDrives[Letter] and FPipeline.State.DrivePresent[Letter];
  for I := 2 to High(FTraySlots) do
    if (FTraySlots[I].DriveLetter <> #0) and (not Wanted[FTraySlots[I].DriveLetter]) then
      ReleaseTraySlot(I);
  for Letter := Low(TDriveLetter) to High(TDriveLetter) do
  begin
    if not Wanted[Letter] then
      Continue;
    Idx := DriveSlotIndex(Letter);
    if Idx < 0 then
    begin
      Idx := FreeDriveSlotIndex;
      if Idx < 0 then
        Exit;
      CreateTraySlot(Idx);
      FTraySlots[Idx].DriveLetter := Letter;
      FTraySlots[Idx].Icon.Hint := 'DiskLED ' + Letter + ':';
      FTraySlots[Idx].Icon.Visible := True;
      FTraySlots[Idx].OffIcon := ComposeLetterIcon(FDriveOffIcon, Letter, GetSystemMetrics(SM_CXSMICON));
      FTraySlots[Idx].OnIcon := ComposeLetterIcon(FDriveOnIcon, Letter, GetSystemMetrics(SM_CXSMICON));
    end;
    UpdateTrayLed(Idx, FPipeline.State.DriveOn[Letter]);
  end;
end;

{ The aggregate disk LED is replaced by the per-drive LEDs while any drive is
  selected, unless TrayLedTotal asks for it too. It stays visible when no drive
  icon is shown, so the tray never ends up with no icon at all. }
procedure TMainForm.UpdateTrayLeds;
var
  I, DriveShown: Integer;
  Letter: TDriveLetter;
  AnyDriveSelected, AggregateHidden: Boolean;
begin
  if FPipeline <> nil then
    SyncDriveTrays;
  DriveShown := 0;
  for I := 2 to High(FTraySlots) do
    if (FTraySlots[I].DriveLetter <> #0) and FTraySlots[I].Icon.Visible then
      Inc(DriveShown);
  AnyDriveSelected := False;
  for Letter := Low(TDriveLetter) to High(TDriveLetter) do
    if FSettings.TrayLedDrives[Letter] then
      AnyDriveSelected := True;
  AggregateHidden := PrimarySourceIsDisk and AnyDriveSelected and
    (not FSettings.TrayLedTotal) and (DriveShown > 0);
  if AggregateHidden then
    HideTraySlot(0)
  else
  begin
    EnsureTraySlot(0);
    UpdateTrayLed(0, TrayLedSourceOn);
  end;
  if BothLedSourcesOn then
  begin
    EnsureTraySlot(1);
    if FPipeline <> nil then
      UpdateTrayLed(1, FPipeline.State.NetActivityOn);
  end
  else
    HideTraySlot(1);
  RefreshDriveHints;
end;

procedure TMainForm.RefreshDriveHints;
const
  CDriveHintIntervalMs = 1000;
var
  I: Integer;
  NowTick: Cardinal;
  Letter: Char;
begin
  if FPipeline = nil then
    Exit;
  NowTick := GetTickCount;
  if FHasDriveHint and ((NowTick - FDriveHintTick) < CDriveHintIntervalMs) then
    Exit;
  FDriveHintTick := NowTick;
  FHasDriveHint := True;
  for I := 2 to High(FTraySlots) do
    if FTraySlots[I].DriveLetter <> #0 then
    begin
      Letter := FTraySlots[I].DriveLetter;
      FTraySlots[I].Icon.Hint := Format(S('tray.drive_rate'), [string(Letter),
        FormatRateBps(FPipeline.Rates.DriveReadBps[Letter]),
        FormatRateBps(FPipeline.Rates.DriveWriteBps[Letter])]);
    end;
end;

procedure TMainForm.RefreshTrayIconForState;
begin
  { Shared by SetWindowTrayState, by Options (LED type/source), and by
    ApplyMode/WMDpiChanged for a mode or DPI change while the LED is showing:
    reload the Off/On icons for whatever type/source is current, then
    re-apply the LED for the live state. When the LED is off, fall back to
    the fixed app icon instead. }
  if FSettings = nil then
    Exit;
  if not FSettings.TrayLed then
  begin
    ResetTrayToAppIcon;
    HideTraySlot(1);
    ReleaseDriveTrays;
    Exit;
  end;
  ReloadTrayIcons;
  FTraySlots[0].HasState := False;
  FTraySlots[1].HasState := False;
  ReleaseDriveTrays;
  UpdateTrayLeds;
end;

procedure TMainForm.SetWindowTrayState(AHidden, ALed: Boolean);
begin
  if FSettings = nil then
    Exit;
  if (FSettings.WindowHidden = AHidden) and (FSettings.TrayLed = ALed) then
  begin
    SyncViewMenu;
    Exit;
  end;
  FSettings.WindowHidden := AHidden;
  FSettings.TrayLed := ALed;
  Visible := not AHidden;
  PersistSettings;
  SyncViewMenu;
  RefreshTrayIconForState;
  if not AHidden then
    BringWindowForward;
end;

procedure TMainForm.LeaveTrayOnly;
begin
  { The "restore to a visible window" entry point used by dblclick,
    second-instance activation, and the reset-position menu item. Drops the
    tray LED too, matching what a plain double-click restored before the LED
    could be kept alongside a visible window; pick "Window + Tray LED" from
    the menu to keep it showing. }
  if (FSettings = nil) or (not FSettings.WindowHidden) then
    Exit;
  SetWindowTrayState(False, False);
end;

procedure TMainForm.miPingResultClick(Sender: TObject);
begin
  { The Ping result window became the dashboard's Ping/route page (3.3.0). }
  ShowDashboardPage(dpRoute);
end;

procedure TMainForm.miDashboardClick(Sender: TObject);
begin
  ShowDashboard;
end;

procedure TMainForm.miResetPositionClick(Sender: TObject);
begin
  { Manual recovery for a window stuck off-screen (e.g. a monitor was
    unplugged): the tray icon stays reachable even then, unlike the body. }

  { The dashboard is a separate top-level window with its own saved position;
    bring it back too, whatever we do with the gadget below. Every path out of
    this handler reaches PersistSettings (directly, or via LeaveTrayOnly ->
    SetWindowTrayState), which persists the dashboard rect, so no explicit save. }
  if FDashboardForm <> nil then
    FDashboardForm.ClampIntoView;

  { Reachable while tray-only too (same popup) - show the window first so
    Visible and FSettings.WindowHidden don't end up disagreeing. }
  if (FSettings <> nil) and FSettings.WindowHidden then
  begin
    LeaveTrayOnly;
    Exit;
  end;
  ApplyWindowBounds;
  PersistSettings;
  BringWindowForward;
end;

function TMainForm.CurrentDrivePresence: TDriveFlags;
begin
  if FPipeline <> nil then
    Result := FPipeline.State.DrivePresent
  else
    Result := Default(TDriveFlags);
end;

procedure TMainForm.miOptionsClick(Sender: TObject);
var
  Applied: Boolean;
  OldHidden: Boolean;
  OldScale: Integer;
begin
  if FSettings = nil then
    Exit;
  OldHidden := FSettings.WindowHidden;
  OldScale := FSettings.Scale;
  FOptionsOpen := True;
  try
    Applied := TOptionsForm.Execute(Self, FSettings, CurrentDrivePresence);
  finally
    FOptionsOpen := False;
  end;
  if Applied then
  begin
    ApplySettingsToUi;
    if FSettings.Scale <> OldScale then
      ApplyScaleChange;
    RefreshTrayIconForState;
    if FSettings.WindowHidden <> OldHidden then
    begin
      Visible := not FSettings.WindowHidden;
      if Visible then
        BringWindowForward;
    end;
    { The dashboard draws its page controls from the settings and drives its
      collectors with them (the Ping target especially): resync it. }
    if FDashboardForm <> nil then
      FDashboardForm.SettingsChanged;
    PersistSettings;
    if UpdateCheckEnabled then
      ScheduleUpdateCheck
    else
      CancelUpdateCheck;
    SyncUpdateMenu;
  end;
  EnsureNoTaskbarButton;
end;

function TMainForm.UpdateCheckEnabled: Boolean;
begin
  { Store builds never check GitHub, regardless of the ini setting: the
    Store version is updated through Microsoft Store, and the same exe is
    shipped both ways so this can't be a compile-time constant. }
  Result := (FSettings <> nil) and FSettings.UpdateEnabled and not IsStorePackage;
end;

procedure TMainForm.SyncUpdateMenu;
var
  Ver: string;
begin
  if FMiUpdate = nil then
    Exit;
  if not UpdateCheckEnabled then
  begin
    FMiUpdate.Visible := False;
    Exit;
  end;
  Ver := NormalizeVersionText(FSettings.UpdateLatestKnown);
  if (Ver <> '') and VersionIsNewer(Ver, GetProductVersionText) then
  begin
    FMiUpdate.Caption := Format(S('menu.update'), [Ver]);
    FMiUpdate.Visible := True;
  end
  else
    FMiUpdate.Visible := False;
end;

procedure TMainForm.ScheduleUpdateCheck;
begin
  Inc(FUpdateGen);
  if FUpdateDelay = nil then
    Exit;
  FUpdateDelay.Enabled := False;
  FUpdateDelay.Interval := 5000;
  FUpdateDelay.Enabled := True;
end;

procedure TMainForm.CancelUpdateCheck;
begin
  Inc(FUpdateGen);
  if FUpdateDelay <> nil then
    FUpdateDelay.Enabled := False;
end;

procedure TMainForm.UpdateDelayTick(Sender: TObject);
var
  Gen: Integer;
begin
  if FUpdateDelay <> nil then
    FUpdateDelay.Enabled := False;
  if FClosing or (not UpdateCheckEnabled) then
    Exit;
  Gen := FUpdateGen;
  TThread.CreateAnonymousThread(
    procedure
    var
      R: TUpdateCheckResult;
    begin
      R.Found := False;
      R.Version := '';
      R.PageUrl := '';
      try
        TryFetchLatestRelease(R);
      except
        R.Found := False;
      end;
      TThread.Queue(nil,
        procedure
        begin
          ApplyUpdateCheckResult(Gen, R);
        end);
    end).Start;
end;

procedure TMainForm.ApplyUpdateCheckResult(AGen: Integer;
  const AResult: TUpdateCheckResult);
var
  Local, Remote: string;
begin
  if FClosing or (csDestroying in ComponentState) then
    Exit;
  if AGen <> FUpdateGen then
    Exit;
  if not UpdateCheckEnabled then
    Exit;
  Local := GetProductVersionText;
  if AResult.Found then
  begin
    Remote := NormalizeVersionText(AResult.Version);
    FSettings.UpdateLatestKnown := Remote;
    { CDebugForceNewerRelease: always re-show the balloon while testing,
      ignoring whether this version was already notified. }
    if VersionIsNewer(Remote, Local) and
      (CDebugForceNewerRelease or
       (not SameText(NormalizeVersionText(FSettings.UpdateLastNotified), Remote))) then
    begin
      ShowUpdateBalloon(Remote);
      FSettings.UpdateLastNotified := Remote;
    end;
    PersistSettings;
  end;
  SyncUpdateMenu;
end;

procedure TMainForm.ShowUpdateBalloon(const AVersion: string);
begin
  if FTraySlots[0].Icon = nil then
    Exit;
  FTraySlots[0].Icon.BalloonTitle := S('tray.update_title');
  FTraySlots[0].Icon.BalloonHint := Format(S('tray.update'), [AVersion]);
  FTraySlots[0].Icon.BalloonFlags := bfInfo;
  FTraySlots[0].Icon.ShowBalloonHint;
end;

procedure TMainForm.OpenUpdatePage;
var
  Url: string;
begin
  if FSettings = nil then
    Exit;
  Url := UpdateReleasePageUrl(FSettings.UpdateLatestKnown);
  if Url = '' then
    Exit;
  ShellExecute(Handle, 'open', PChar(Url), nil, nil, SW_SHOWNORMAL);
end;

procedure TMainForm.miUpdateClick(Sender: TObject);
begin
  OpenUpdatePage;
end;

procedure TMainForm.TrayBalloonClick(Sender: TObject);
begin
  OpenUpdatePage;
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

{ Shared by both tray icons; the slot is found from Sender so each icon keeps
  its own click-delay timer. }

procedure TMainForm.TrayDblClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TraySlotOf(Sender);
  if Index < 0 then
    Exit;
  FTraySlots[Index].ClickDelay.Enabled := False;
  if (FSettings <> nil) and FSettings.WindowHidden then
    LeaveTrayOnly
  else
    BringWindowForward;
end;

procedure TMainForm.TrayClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TraySlotOf(Sender);
  if Index < 0 then
    Exit;
  { Deferred so the first click of a double-click doesn't also open the
    dashboard: TrayDblClick cancels this timer before it fires. }
  FTraySlots[Index].ClickDelay.Enabled := False;
  FTraySlots[Index].ClickDelay.Enabled := True;
end;

procedure TMainForm.TrayClickDelayTick(Sender: TObject);
var
  Index: Integer;
begin
  Index := TraySlotOf(Sender);
  if Index < 0 then
    Exit;
  FTraySlots[Index].ClickDelay.Enabled := False;
  ShowDashboard;
end;

procedure TMainForm.ShowAppPopup(AX, AY: Integer);
begin
  HideHoverTip;
  if FPopup = nil then
    Exit;
  SyncModeChecks;
  if (AX = -1) and (AY = -1) then
    FPopup.Popup(Left + 8, Top + 8)
  else
    FPopup.Popup(AX, AY);
end;

procedure TMainForm.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TMainForm.WMNCHitTest(var Message: TWMNCHitTest);
begin
  inherited;
  { Drag by treating the face as caption. Double-click → WM_NCLBUTTONDBLCLK. }
  if Message.Result = HTCLIENT then
    Message.Result := HTCAPTION;
end;

procedure TMainForm.WMNCLButtonDblClk(var Message: TWMNCLButtonDblClk);
begin
  if Message.HitTest = HTCAPTION then
    ToggleCompactFull
  else
    inherited;
end;

procedure TMainForm.WMNCRButtonUp(var Message: TWMNCRButtonUp);
begin
  ShowAppPopup(Message.XCursor, Message.YCursor);
  Message.Result := 0;
end;

procedure TMainForm.WMContextMenu(var Message: TWMContextMenu);
begin
  ShowAppPopup(Message.XPos, Message.YPos);
  Message.Result := 1;
end;

procedure TMainForm.WMSysCommand(var Message: TWMSysCommand);
begin
  case (Message.CmdType and $FFF0) of
    SC_MAXIMIZE, SC_MINIMIZE, SC_RESTORE, SC_MOUSEMENU, SC_KEYMENU:
      Exit;
  end;
  inherited;
end;

procedure TMainForm.WMDpiChanged(var Message: TMessage);
var
  Suggested: TRect;
begin
  FMonitorDpi := LoWord(Message.WParam);
  if FMonitorDpi < 1 then
    FMonitorDpi := MonitorDpiForWindow(Handle);
  { Fixed scale ignores the DPI change for sizing; the suggested-rect move
    below still runs so the gadget follows the cursor to the new monitor. }
  FScale100 := ResolveScale100;
  ApplyDpiClientSize;
  RefreshTrayIconForState;
  if Message.LParam <> 0 then
  begin
    Suggested := PRect(Message.LParam)^;
    SetBounds(Suggested.Left, Suggested.Top, Width, Height);
  end;
  { Same taskbar-settle re-clamp as the polled path (see PollMonitorDpiChange):
    covers configs where a same-monitor scale change does deliver this. }
  FDpiSettleTicks := 30;
  Invalidate;
  Message.Result := 0;
end;

procedure TMainForm.WMDisplayChange(var Message: TMessage);
begin
  { Resolution/monitor-layout changes while running: re-clamp into the
    (possibly now-different) work area. Startup already clamps via
    ApplyWindowBounds in FormCreate; this covers the same case mid-session. }
  ApplyWindowBounds;
  PersistSettings;
  inherited;
end;

procedure TMainForm.WMMoving(var Message: TMessage);
begin
  ApplyGadgetDragRect(FGadgetDrag, PRect(Message.LParam)^, FMonitorDpi);
  Message.Result := 1;
end;

procedure TMainForm.WMEnterSizeMove(var Message: TMessage);
begin
  FDragging := True;
  BeginGadgetDrag(FGadgetDrag, BoundsRect);
  HideHoverTip;
  inherited;
end;

procedure TMainForm.WMExitSizeMove(var Message: TMessage);
begin
  FDragging := False;
  EndGadgetDrag(FGadgetDrag);
  ApplyWindowBounds;
  PersistSettings;
  inherited;
end;

procedure TMainForm.WMNCLButtonDown(var Message: TWMNCLButtonDown);
begin
  HideHoverTip;
  inherited;
end;

procedure TMainForm.ArmNcMouseLeave;
var
  Tme: TTrackMouseEvent;
begin
  if not HandleAllocated then
    Exit;
  FillChar(Tme, SizeOf(Tme), 0);
  Tme.cbSize := SizeOf(Tme);
  Tme.dwFlags := TME_LEAVE or TME_NONCLIENT;
  Tme.hwndTrack := Handle;
  TrackMouseEvent(Tme);
end;

procedure TMainForm.HideHoverTip;
begin
  FHoverArmed := False;
  if FHoverDelay <> nil then
    FHoverDelay.Enabled := False;
  if FHoverTip <> nil then
    FHoverTip.Hide;
end;

function TMainForm.HoverInfoText: string;
var
  CpuPct, MemPct, SwapPct: Integer;
  DiskIo, NetIo: string;
  PingLine: string;
  Snap: TMetricsSnapshot;
  Host: string;
begin
  CpuPct := 0;
  MemPct := 0;
  SwapPct := 0;
  DiskIo := FormatRateBps(0);
  NetIo := FormatRateBps(0);
  PingLine := 'Ping: ' + S('hover.ping_off');
  if FPipeline <> nil then
  begin
    CpuPct := Round(Clamp01(FPipeline.State.CpuDigit) * 100);
    MemPct := Round(Clamp01(FPipeline.State.MemDigit) * 100);
    SwapPct := Round(Clamp01(FPipeline.State.SwapDigit) * 100);
    Snap := FPipeline.LastSnap;
    DiskIo := FormatRateBps(FPipeline.Rates.DiskReadBps + FPipeline.Rates.DiskWriteBps);
    NetIo := FormatRateBps(FPipeline.Rates.NetInBps + FPipeline.Rates.NetOutBps);
    Host := Trim(Snap.PingTarget);
    if not Snap.PingEnabled then
      PingLine := 'Ping: ' + S('hover.ping_off')
    else if Snap.PingOk then
    begin
      if Host <> '' then
        PingLine := Format('Ping: %dms (%s)', [Round(Snap.PingRttMs), Host])
      else
        PingLine := Format('Ping: %dms', [Round(Snap.PingRttMs)]);
    end
    else if Snap.PingPending then
    begin
      if Host <> '' then
        PingLine := Format('Ping: %s (%s)', [S('hover.ping_pending'), Host])
      else
        PingLine := 'Ping: ' + S('hover.ping_pending');
    end
    else
    begin
      if Host <> '' then
        PingLine := Format('Ping: %s (%s)', [S('hover.ping_timeout'), Host])
      else
        PingLine := 'Ping: ' + S('hover.ping_timeout');
    end;
  end;
  if FVersionText = '' then
    FVersionText := GetProductVersionText;
  { EditionSuffix is ' (Store)' on the MSIX build, '' otherwise — lets a support
    screenshot tell the Store and GitHub editions apart. Disk/Net labels are
    kept short so the whole block still fits the tray hint's 128-char cap. }
  Result := Format(
    'DiskLED %s%s'#13#10 +
    ' CPU: %d%%'#13#10 +
    ' MEM: %d%%'#13#10 +
    ' SWP: %d%%'#13#10 +
    ' Disk: %s'#13#10 +
    ' Net: %s'#13#10 +
    ' %s',
    [FVersionText, EditionSuffix, CpuPct, MemPct, SwapPct, DiskIo, NetIo, PingLine]);
end;

procedure TMainForm.RefreshHoverText;
const
  CHoverIntervalMs = 1000;
var
  NowTick: Cardinal;
  Text: string;
begin
  NowTick := GetTickCount;
  if FHasHoverText and ((NowTick - FHoverTextTick) < CHoverIntervalMs) then
    Exit;
  Text := HoverInfoText;
  FHoverHeldText := Text;
  FHoverTextTick := NowTick;
  FHasHoverText := True;
  if FHoverTip <> nil then
    FHoverTip.UpdateText(Text);
  if FTraySlots[0].Icon <> nil then
    FTraySlots[0].Icon.Hint := Text;
  if FTraySlots[1].Icon <> nil then
    FTraySlots[1].Icon.Hint := Text;
end;

procedure TMainForm.HoverDelayTick(Sender: TObject);
begin
  if FHoverDelay <> nil then
    FHoverDelay.Enabled := False;
  if FDragging or (FHoverTip = nil) then
    Exit;
  RefreshHoverText;
  FHoverTip.SetOwner(Handle);
  if FHoverHeldText = '' then
    FHoverHeldText := HoverInfoText;
  FHoverTip.ShowAtCursor(FHoverHeldText);
end;

procedure TMainForm.WMNCMouseMove(var Message: TWMMouse);
begin
  inherited;
  if FDragging then
    Exit;
  ArmNcMouseLeave;
  if FHoverTip = nil then
    Exit;
  if FHoverTip.Visible then
    Exit;
  if FHoverArmed then
    Exit;
  FHoverArmed := True;
  if FHoverDelay <> nil then
  begin
    FHoverDelay.Enabled := False;
    FHoverDelay.Enabled := True;
  end;
end;

procedure TMainForm.WMNCMouseLeave(var Message: TMessage);
begin
  HideHoverTip;
  inherited;
end;

end.
