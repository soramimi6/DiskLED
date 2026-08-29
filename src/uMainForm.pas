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
  uAssetStore,
  uCollector,
  uDisplayPipeline,
  uHistoryBuffer,
  uSettings,
  uHoverTip,
  uMeterRenderer;

type
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
    FTray: TTrayIcon;
    FAssetsRoot: string;
    FReadyToPersist: Boolean;
    FLastGraphTick: Cardinal;
    FHasGraphTick: Boolean;
    FGraphPeak: THistorySample;
    FGraphGen: Cardinal;
    FLastFp: TVisualFingerprint;
    FHasFp: Boolean;
    FMiCompact: TMenuItem;
    FMiFull: TMenuItem;
    FHoverTip: THoverTip;
    FHoverDelay: TTimer;
    FHoverArmed: Boolean;
    FDragging: Boolean;
    FVersionText: string;
    FHoverHeldText: string;
    FHoverTextTick: Cardinal;
    FHasHoverText: Boolean;
    procedure BuildPopup;
    procedure ApplyMode(const AModeId: string);
    procedure ApplyViewSize;
    procedure ResetGraphPeak;
    procedure ToggleCompactFull;
    procedure SetCompactView(ACompact: Boolean);
    procedure Render;
    procedure SyncModeChecks;
    procedure SyncViewMenu;
    procedure TimerTick(Sender: TObject);
    procedure miModeClick(Sender: TObject);
    procedure miCompactClick(Sender: TObject);
    procedure miFullClick(Sender: TObject);
    procedure miPingClick(Sender: TObject);
    procedure miOptionsClick(Sender: TObject);
    procedure miExitClick(Sender: TObject);
    procedure TrayDblClick(Sender: TObject);
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMNCRButtonUp(var Message: TWMNCRButtonUp); message WM_NCRBUTTONUP;
    procedure WMContextMenu(var Message: TWMContextMenu); message WM_CONTEXTMENU;
    procedure WMSysCommand(var Message: TWMSysCommand); message WM_SYSCOMMAND;
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
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
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
  uWindowPlacement,
  uOptionsForm,
  uStartup,
  uMetricsTypes;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { Unowned + APPWINDOW => taskbar. Owned tool window => no button. }
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
  { poDesigned: do not let VCL recenter and wipe restored Left/Top. }
  Position := poDesigned;

  FSettings := TAppSettings.Create;
  FSettings.Load;
  FSettings.Startup := TStartup.IsRegistered;

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
  FHasGraphTick := False;
  ResetGraphPeak;
  FTimer := TTimer.Create(Self);
  FTimer.OnTimer := TimerTick;

  BuildPopup;
  PopupMenu := FPopup;
  SetupTray;
  EnsureNoTaskbarButton;

  ApplySettingsToUi;
  { Size for mode first, then apply saved position (no Persist yet). }
  ApplyMode(FSettings.Mode);
  SetBounds(FSettings.WindowX, FSettings.WindowY, Width, Height);
  ApplyWindowBounds;
  CaptureWindowPosToSettings;
  FReadyToPersist := True;
  { Write back clamped position so next launch matches what user sees. }
  PersistSettings;

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
  FTray := TTrayIcon.Create(Self);
  if FileExists(MainIconPath) then
  try
    FTray.Icon.LoadFromFile(MainIconPath);
  except
    try
      FTray.Icon.Assign(Icon);
    except
    end;
  end
  else
  try
    FTray.Icon.Assign(Icon);
  except
  end;
  FTray.Hint := 'DiskLED';
  FTray.PopupMenu := FPopup;
  FTray.OnDblClick := TrayDblClick;
  FTray.Visible := True;
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
  try
    FSettings.Save;
  except
  end;
end;

procedure TMainForm.ApplyStartupRegistration;
begin
  if (FSettings = nil) or (not FReadyToPersist) then
    Exit;
  try
    TStartup.SetRegistered(FSettings.Startup);
  except
  end;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if FHoverDelay <> nil then
    FHoverDelay.Enabled := False;
  HideHoverTip;
  FreeAndNil(FHoverTip);
  if FTimer <> nil then
    FTimer.Enabled := False;
  FCollector.Free;
  FPipeline.Free;
  FHistory.Free;
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
  miPing: TMenuItem;
  miOpt: TMenuItem;
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

  miPing := TMenuItem.Create(FPopup);
  miPing.Caption := S('menu.ping');
  miPing.OnClick := miPingClick;
  FPopup.Items.Add(miPing);

  miOpt := TMenuItem.Create(FPopup);
  miOpt.Caption := S('menu.options');
  miOpt.OnClick := miOptionsClick;
  FPopup.Items.Add(miOpt);

  Sep := TMenuItem.Create(FPopup);
  Sep.Caption := '-';
  FPopup.Items.Add(Sep);

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
end;

function TMainForm.UsingFullView: Boolean;
begin
  Result := FHasFull and (FSettings <> nil) and (not FSettings.Compact);
end;

procedure TMainForm.ResetGraphPeak;
begin
  FGraphPeak := ZeroHistorySample;
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
    FPipeline.ApplyBallistics(FLayout.Ballistics);
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
  ConstrainAndSnapRect(R);
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
  { Compact layout always exists; Full only when [ModeFull] is defined. }
  FMiCompact.Enabled := True;
  FMiFull.Enabled := FHasFull;
  InFull := UsingFullView;
  FMiCompact.Checked := not InFull;
  FMiFull.Checked := InFull;
end;

procedure TMainForm.Render;
begin
  if (FAssets = nil) or (FBuffer = nil) then
    Exit;
  if (FLayout.Width < 1) or (FLayout.Height < 1) or (FLayout.BgFile = '') then
    Exit;
  FBuffer.SetSize(FLayout.Width, FLayout.Height);
  TMeterRenderer.DrawBackground(FBuffer.Canvas, FLayout, FAssets);
  if FPipeline <> nil then
    TMeterRenderer.DrawMeters(FBuffer.Canvas, FLayout, FAssets, FPipeline.State);
  if UsingFullView and (FHistory <> nil) and FLayout.Graph.Enabled then
    TGraphRenderer.Draw(FBuffer.Canvas, FLayout.Graph, FHistory);
end;

procedure TMainForm.TimerTick(Sender: TObject);
var
  IntervalMs: Cardinal;
  NowTick: Cardinal;
  Sample: THistorySample;
  GraphKey: Cardinal;
  Fp: TVisualFingerprint;
begin
  if (FCollector = nil) or (FPipeline = nil) then
    Exit;
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
  RefreshHoverText;
end;

procedure TMainForm.FormPaint(Sender: TObject);
begin
  if FBuffer <> nil then
    Canvas.Draw(0, 0, FBuffer);
end;

procedure TMainForm.miModeClick(Sender: TObject);
begin
  ApplyMode(TMenuItem(Sender).Hint);
end;

procedure TMainForm.miCompactClick(Sender: TObject);
begin
  SetCompactView(True);
end;

procedure TMainForm.miFullClick(Sender: TObject);
begin
  SetCompactView(False);
end;

procedure TMainForm.miPingClick(Sender: TObject);
begin
  if FCollector <> nil then
    FCollector.RequestPing;
end;

procedure TMainForm.miOptionsClick(Sender: TObject);
begin
  if FSettings = nil then
    Exit;
  if TOptionsForm.Execute(Self, FSettings) then
  begin
    ApplySettingsToUi;
    PersistSettings;
  end;
  EnsureNoTaskbarButton;
end;

procedure TMainForm.miExitClick(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.TrayDblClick(Sender: TObject);
begin
  BringWindowForward;
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

procedure TMainForm.WMMoving(var Message: TMessage);
begin
  ConstrainAndSnapRect(PRect(Message.LParam)^);
  Message.Result := 1;
end;

procedure TMainForm.WMEnterSizeMove(var Message: TMessage);
begin
  FDragging := True;
  HideHoverTip;
  inherited;
end;

procedure TMainForm.WMExitSizeMove(var Message: TMessage);
begin
  FDragging := False;
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
    DiskIo := FormatRateBps(Snap.DiskReadBps + Snap.DiskWriteBps);
    NetIo := FormatRateBps(Snap.NetInBps + Snap.NetOutBps);
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
  Result := Format(
    'DiskLED %s'#13#10 +
    ' CPU: %d%%'#13#10 +
    ' MEM: %d%%'#13#10 +
    ' SWP: %d%%'#13#10 +
    ' Disk I/O: %s'#13#10 +
    ' Net I/O: %s'#13#10 +
    ' %s',
    [FVersionText, CpuPct, MemPct, SwapPct, DiskIo, NetIo, PingLine]);
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
  if FTray <> nil then
    FTray.Hint := Text;
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
