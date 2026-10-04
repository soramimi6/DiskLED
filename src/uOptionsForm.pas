unit uOptionsForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.ComCtrls,
  Vcl.Graphics,
  Vcl.CheckLst,
  uMetricsTypes,
  uSettings;

type
  TDrivePresenceFunc = function: TDriveFlags of object;

  TOptionsForm = class(TForm)
    PageControl1: TPageControl;
    TsGeneral: TTabSheet;
    TsDisplay: TTabSheet;
    TsTrayLed: TTabSheet;
    TsPing: TTabSheet;
    CardWindow: TPanel;
    LblSecWindow: TLabel;
    ChkStayOnTop: TCheckBox;
    ChkStartup: TCheckBox;
    ChkUpdateCheck: TCheckBox;
    LblStartupBlocked: TLabel;
    LblLanguage: TLabel;
    CbLanguage: TComboBox;
    LblLanguageHint: TLabel;
    CardFps: TPanel;
    LblSecFps: TLabel;
    RbFps10: TRadioButton;
    RbFps15: TRadioButton;
    RbFps20: TRadioButton;
    LblSecGraph: TLabel;
    PnlGraphRates: TPanel;
    RbGraph2: TRadioButton;
    RbGraph1: TRadioButton;
    RbGraph05: TRadioButton;
    CardScale: TPanel;
    LblSecScale: TLabel;
    RbScaleLinear: TRadioButton;
    RbScaleLog: TRadioButton;
    CardTrayLed: TPanel;
    LblSecTrayLedColor: TLabel;
    LblSecTrayLedInfo: TLabel;
    ImgLedGreen: TImage;
    ImgLedBlue: TImage;
    ImgLedRed: TImage;
    ImgLedYellow: TImage;
    LblLedGreen: TLabel;
    LblLedBlue: TLabel;
    LblLedRed: TLabel;
    LblLedYellow: TLabel;
    PnlLedDisk: TPanel;
    LblLedDisk: TLabel;
    RbLedDiskGreen: TRadioButton;
    RbLedDiskBlue: TRadioButton;
    RbLedDiskRed: TRadioButton;
    RbLedDiskYellow: TRadioButton;
    PnlLedNet: TPanel;
    LblLedNet: TLabel;
    RbLedNetGreen: TRadioButton;
    RbLedNetBlue: TRadioButton;
    RbLedNetRed: TRadioButton;
    RbLedNetYellow: TRadioButton;
    ChkLedDisk: TCheckBox;
    ChkLedNet: TCheckBox;
    LblSecTrayDrives: TLabel;
    ChkLedTotal: TCheckBox;
    LstDrives: TCheckListBox;
    LblSecWindowMode: TLabel;
    RbWinOnly: TRadioButton;
    RbWinTrayLed: TRadioButton;
    RbTrayOnly: TRadioButton;
    CardDisplayScale: TPanel;
    LblSecDisplayScale: TLabel;
    RbScaleAuto: TRadioButton;
    RbScale100: TRadioButton;
    RbScale150: TRadioButton;
    RbScale200: TRadioButton;
    CardPing: TPanel;
    LblSecPing: TLabel;
    ChkPingEnabled: TCheckBox;
    ChkAutoGw: TCheckBox;
    LblHost: TLabel;
    EdHost: TEdit;
    LblInterval: TLabel;
    EdInterval: TEdit;
    CardThresholds: TPanel;
    LblSecThresholds: TLabel;
    LblFair: TLabel;
    EdFair: TEdit;
    LblSlow: TLabel;
    EdSlow: TEdit;
    LblTimeout: TLabel;
    EdTimeout: TEdit;
    BtnResetThresholds: TButton;
    PnlButtons: TPanel;
    ShpButtonTop: TShape;
    BtnOk: TButton;
    BtnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ChkPingEnabledClick(Sender: TObject);
    procedure ChkAutoGwClick(Sender: TObject);
    procedure ChkLedDiskClick(Sender: TObject);
    procedure ChkLedNetClick(Sender: TObject);
    procedure BtnResetThresholdsClick(Sender: TObject);
    procedure BtnOkClick(Sender: TObject);
  private
    FSettings: TAppSettings;
    FPresent: TDriveFlags;
    FDrivePresence: TDrivePresenceFunc;
    FDriveTimer: TTimer;
    procedure RebuildDriveList(const AChecked: TDriveFlags);
    procedure DriveTimerTick(Sender: TObject);
    procedure ApplyCaptions;
    procedure LoadFromSettings;
    function CheckedDrives: TDriveFlags;
    procedure LoadLedPreviewIcons;
    procedure SyncPingControlsEnabled;
    function TryParseInt(const S: string; out AValue: Integer): Boolean;
    function ValidateInputs(out AInterval, AFair, ASlow, ATimeout: Integer): Boolean;
    procedure ShowValidationError(const AMessage: string);
  public
    procedure BindSettings(ASettings: TAppSettings; APresence: TDrivePresenceFunc);
    class function Execute(AOwner: TComponent; ASettings: TAppSettings;
      APresence: TDrivePresenceFunc): Boolean; static;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  end;

var
  OptionsForm: TOptionsForm;

implementation

{$R *.dfm}

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.CommCtrl,
  uAppStrings,
  uStartup,
  uPackaging,
  uAssetStore;

const
  CDefaultFairMs = 200;
  CDefaultSlowMs = 500;
  CDefaultTimeoutMs = 1000;
  CMinIntervalSec = 300;

procedure TOptionsForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { Keeps Options off the taskbar / Alt+Tab, as the tray-centric gadget's own
    window does (uMainForm.CreateParams). }
  Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
end;

procedure TOptionsForm.FormCreate(Sender: TObject);
begin
  SyncPingControlsEnabled;
  LoadLedPreviewIcons;
  FDriveTimer := TTimer.Create(Self);
  FDriveTimer.Enabled := False;
  FDriveTimer.Interval := 1000;
  FDriveTimer.OnTimer := DriveTimerTick;
end;

procedure TOptionsForm.DriveTimerTick(Sender: TObject);
var
  NewPresent: TDriveFlags;
begin
  if not Assigned(FDrivePresence) then
    Exit;
  NewPresent := FDrivePresence();
  if CompareMem(@NewPresent, @FPresent, SizeOf(NewPresent)) then
    Exit;
  FPresent := NewPresent;
  RebuildDriveList(CheckedDrives);
end;

function DriveTypeName(ADriveType: Cardinal): string;
begin
  case ADriveType of
    DRIVE_FIXED: Result := S('drive.fixed');
    DRIVE_REMOVABLE: Result := S('drive.removable');
    DRIVE_CDROM: Result := S('drive.optical');
    DRIVE_REMOTE: Result := S('drive.network');
  else
    Result := '';
  end;
end;

{ Lists the drives that are present (PDH reports them), plus optical drives
  (shown but unselectable: PDH and the disk IOCTL never report activity for
  them), plus any that are selected or currently checked. Virtual or unmounted
  letters are left out, so they never appear as dead entries. }
procedure TOptionsForm.RebuildDriveList(const AChecked: TDriveFlags);
var
  Letter: TDriveLetter;
  Index, DriveType: Integer;
  Optical: Boolean;
  Text, TypeName: string;
begin
  LstDrives.Items.BeginUpdate;
  try
    LstDrives.Items.Clear;
    for Letter := Low(TDriveLetter) to High(TDriveLetter) do
    begin
      DriveType := Integer(GetDriveType(PChar(string(Letter) + ':\')));
      Optical := DriveType = DRIVE_CDROM;
      if not (FPresent[Letter] or Optical or FSettings.TrayLedDrives[Letter] or
        AChecked[Letter]) then
        Continue;
      Text := Letter + ':';
      TypeName := DriveTypeName(DriveType);
      if TypeName <> '' then
        Text := Text + ' ' + TypeName;
      if Optical then
        Text := Text + S('drive.unsupported')
      else if not FPresent[Letter] then
        Text := Text + S('opt.tray_drive_absent');
      Index := LstDrives.Items.Add(Text);
      LstDrives.ItemEnabled[Index] := not Optical;
      LstDrives.Checked[Index] := AChecked[Letter] and (not Optical);
    end;
  finally
    LstDrives.Items.EndUpdate;
  end;
end;

const
  { Tray LED color ids, in the column order of the Options color matrix
    (each radio row lists its buttons in this order). }
  CLedColors: array[0..3] of string = ('green', 'blue', 'red', 'yellow');

{ Checks the button for AColor in one matrix row; green when unknown. }
procedure CheckLedColor(const AButtons: array of TRadioButton; const AColor: string);
var
  i: Integer;
begin
  for i := 0 to High(CLedColors) do
    if SameText(AColor, CLedColors[i]) then
    begin
      AButtons[i].Checked := True;
      Exit;
    end;
  AButtons[0].Checked := True;
end;

function CheckedLedColor(const AButtons: array of TRadioButton): string;
var
  i: Integer;
begin
  for i := 0 to High(CLedColors) do
    if AButtons[i].Checked then
      Exit(CLedColors[i]);
  Result := CLedColors[0];
end;

procedure TOptionsForm.LoadLedPreviewIcons;
var
  Root: string;
  Icon: TIcon;

  procedure Load(AImg: TImage; const AColor: string);
  begin
    { LIM_SMALL, like the real tray icon: the swatch is 16 DIP, which the
      scaled Options form sizes to SM_CXSMICON, so the matching icon frame is
      drawn without resampling. }
    Icon := TAssetStore.LoadIconFile(
      TAssetStore.BuildPath(Root, 'tray' + PathDelim + AColor, 'diskOn.ico'), LIM_SMALL);
    try
      AImg.Picture.Assign(Icon);
    finally
      Icon.Free;
    end;
  end;

begin
  Root := TAssetStore.LocateRoot;
  { diskOn (the plain lit sphere, no glyph) is the clearest color swatch --
    the net glyph would only distract from the color being previewed. }
  Load(ImgLedGreen, 'green');
  Load(ImgLedBlue, 'blue');
  Load(ImgLedRed, 'red');
  Load(ImgLedYellow, 'yellow');
end;

procedure TOptionsForm.BindSettings(ASettings: TAppSettings; APresence: TDrivePresenceFunc);
begin
  FSettings := ASettings;
  FDrivePresence := APresence;
  if Assigned(FDrivePresence) then
    FPresent := FDrivePresence()
  else
    FPresent := Default(TDriveFlags);
  FDriveTimer.Enabled := True;
  ApplyCaptions;
  LoadFromSettings;
end;

procedure TOptionsForm.ApplyCaptions;
begin
  Caption := S('opt.title');
  TsGeneral.Caption := S('opt.tab.general');
  TsDisplay.Caption := S('opt.tab.display');
  TsTrayLed.Caption := S('opt.tab.tray_led');
  TsPing.Caption := S('opt.tab.ping');
  LblSecWindow.Caption := S('opt.group.window');
  LblLanguage.Caption := S('opt.language');
  LblLanguageHint.Caption := S('opt.language_restart_hint');
  ChkStayOnTop.Caption := S('opt.stay_on_top');
  ChkStartup.Caption := S('opt.startup');
  ChkUpdateCheck.Caption := S('opt.update_check');
  LblStartupBlocked.Caption := S('opt.startup_blocked');
  LblSecFps.Caption := S('opt.fps');
  LblSecGraph.Caption := S('opt.graph_rate');
  LblSecScale.Caption := S('opt.speed_scale');
  RbScaleLinear.Caption := S('opt.speed_scale_linear');
  RbScaleLog.Caption := S('opt.speed_scale_log');
  LblSecTrayLedColor.Caption := S('opt.tray_led_color');
  LblLedGreen.Caption := S('opt.tray_led_color_green');
  LblLedBlue.Caption := S('opt.tray_led_color_blue');
  LblLedRed.Caption := S('opt.tray_led_color_red');
  LblLedYellow.Caption := S('opt.tray_led_color_yellow');
  LblLedDisk.Caption := S('opt.tray_led_info_disk');
  LblLedNet.Caption := S('opt.tray_led_info_net');
  LblSecTrayLedInfo.Caption := S('opt.tray_led_info');
  LblSecTrayDrives.Caption := S('opt.tray_drives');
  ChkLedTotal.Caption := S('opt.tray_drive_total');
  LblSecWindowMode.Caption := S('opt.window_mode');
  RbWinOnly.Caption := S('menu.window_only');
  RbWinTrayLed.Caption := S('menu.window_tray_led');
  RbTrayOnly.Caption := S('menu.tray_only');
  LblSecDisplayScale.Caption := S('menu.scale');
  RbScaleAuto.Caption := S('menu.scale_auto');
  ChkLedDisk.Caption := S('opt.tray_led_info_disk');
  ChkLedNet.Caption := S('opt.tray_led_info_net');
  LblSecPing.Caption := S('opt.group.ping');
  ChkPingEnabled.Caption := S('opt.ping_enabled');
  ChkAutoGw.Caption := S('opt.ping_auto_gw');
  LblHost.Caption := S('opt.ping_host');
  LblInterval.Caption := S('opt.ping_interval');
  LblSecThresholds.Caption := S('opt.group.thresholds');
  LblFair.Caption := S('opt.ping_fair_short');
  LblSlow.Caption := S('opt.ping_slow_short');
  LblTimeout.Caption := S('opt.ping_timeout_short');
  BtnResetThresholds.Caption := S('opt.ping_reset_thresholds');
  BtnOk.Caption := S('opt.apply');
  BtnCancel.Caption := S('opt.cancel');
end;

procedure TOptionsForm.SyncPingControlsEnabled;
var
  PingOn: Boolean;
begin
  PingOn := ChkPingEnabled.Checked;

  ChkAutoGw.Enabled := PingOn;
  LblInterval.Enabled := PingOn;
  EdInterval.Enabled := PingOn;

  LblSecThresholds.Enabled := PingOn;
  LblFair.Enabled := PingOn;
  EdFair.Enabled := PingOn;
  LblSlow.Enabled := PingOn;
  EdSlow.Enabled := PingOn;
  LblTimeout.Enabled := PingOn;
  EdTimeout.Enabled := PingOn;
  BtnResetThresholds.Enabled := PingOn;
  CardThresholds.Enabled := PingOn;

  { Host is editable only when Ping is on and default gateway is off. }
  EdHost.Enabled := PingOn and (not ChkAutoGw.Checked);
  LblHost.Enabled := EdHost.Enabled;
end;

procedure TOptionsForm.ChkPingEnabledClick(Sender: TObject);
begin
  SyncPingControlsEnabled;
end;

procedure TOptionsForm.ChkAutoGwClick(Sender: TObject);
begin
  SyncPingControlsEnabled;
end;

procedure TOptionsForm.ChkLedDiskClick(Sender: TObject);
begin
  { Unchecking this would leave both off (nothing for the tray LED to show):
    cancel the uncheck by putting it straight back on. Checked := True here
    does not itself fire OnClick, so this does not recurse. }
  if (not ChkLedDisk.Checked) and (not ChkLedNet.Checked) then
    ChkLedDisk.Checked := True;
end;

procedure TOptionsForm.ChkLedNetClick(Sender: TObject);
begin
  if (not ChkLedNet.Checked) and (not ChkLedDisk.Checked) then
    ChkLedNet.Checked := True;
end;

function TOptionsForm.CheckedDrives: TDriveFlags;
var
  I: Integer;
begin
  Result := Default(TDriveFlags);
  for I := 0 to LstDrives.Items.Count - 1 do
    if LstDrives.Checked[I] then
      Result[LstDrives.Items[I][1]] := True;
end;

procedure TOptionsForm.BtnResetThresholdsClick(Sender: TObject);
begin
  EdFair.Text := IntToStr(CDefaultFairMs);
  EdSlow.Text := IntToStr(CDefaultSlowMs);
  EdTimeout.Text := IntToStr(CDefaultTimeoutMs);
end;

procedure TOptionsForm.LoadFromSettings;
var
  StartupOn, StartupBlocked, StartupUnknown: Boolean;
begin
  if FSettings = nil then
    Exit;
  ChkStayOnTop.Checked := FSettings.StayOnTop;

  if SameText(FSettings.Language, 'ja') then
    CbLanguage.ItemIndex := 1
  else if SameText(FSettings.Language, 'en') then
    CbLanguage.ItemIndex := 2
  else
    CbLanguage.ItemIndex := 0;

  if TStartup.EnablePending then
  begin
    { A previous "enable" is still settling (its consent prompt may still be
      on screen). Keep the checkbox out of the loop instead of letting a
      same-session disable race it -- see StoreSetRegistered (uStartup.pas)
      for what used to happen if that race was allowed to occur. }
    ChkStartup.Checked := True;
    ChkStartup.Enabled := False;
    LblStartupBlocked.Caption := S('opt.startup_pending');
    LblStartupBlocked.Visible := True;
  end
  else
  begin
    { One state read for the checkbox value, the blocked state, and whether
      the read itself failed. On the Store build this is the authoritative
      StartupTask state; OR-ing the persisted flag would mask a task Windows
      reports as disabled. Off Store, keep the OR so a just-written Run key
      still shows. }
    TStartup.QueryState(StartupOn, StartupBlocked, StartupUnknown);
    if StartupUnknown then
    begin
      { Could not determine the real state (transient WinRT failure). Show
        the last-saved value but disable the control so Save cannot persist
        or act on an unconfirmed answer -- a stale correct value is safer
        than a wrong one written back with confidence. }
      ChkStartup.Checked := FSettings.Startup;
      ChkStartup.Enabled := False;
      LblStartupBlocked.Caption := S('opt.startup_unknown');
      LblStartupBlocked.Visible := True;
    end
    else if StartupBlocked then
    begin
      { Store build: the task can be disabled from Task Manager / Settings and
        RequestEnableAsync cannot override that -- surface it. }
      ChkStartup.Checked := False;
      ChkStartup.Enabled := False;
      LblStartupBlocked.Caption := S('opt.startup_blocked');
      LblStartupBlocked.Visible := True;
    end
    else
    begin
      if IsStorePackage then
        ChkStartup.Checked := StartupOn
      else
        ChkStartup.Checked := StartupOn or FSettings.Startup;
      ChkStartup.Enabled := True;
      LblStartupBlocked.Visible := False;
    end;
  end;

  ChkUpdateCheck.Checked := FSettings.UpdateEnabled;
  { Store builds update through Microsoft Store, not GitHub; hide the
    now-irrelevant option rather than leave a checkbox with no effect.
    LblStartupBlocked (.dfm) sits at the same coordinates as this checkbox and
    is only ever made Visible on Store builds -- the two are mutually
    exclusive by construction, reusing the row instead of overlapping. Keep
    that pairing in mind before changing either control's Visible logic. }
  ChkUpdateCheck.Visible := not IsStorePackage;
  case FSettings.Fps of
    10:
      RbFps10.Checked := True;
    20:
      RbFps20.Checked := True;
  else
    RbFps15.Checked := True;
  end;
  if Abs(FSettings.GraphRateHz - 2.0) < 0.01 then
    RbGraph2.Checked := True
  else if Abs(FSettings.GraphRateHz - 0.5) < 0.01 then
    RbGraph05.Checked := True
  else
    RbGraph1.Checked := True;
  if FSettings.SpeedScale = ssLog then
    RbScaleLog.Checked := True
  else
    RbScaleLinear.Checked := True;
  CheckLedColor([RbLedDiskGreen, RbLedDiskBlue, RbLedDiskRed, RbLedDiskYellow],
    FSettings.TrayLedType);
  CheckLedColor([RbLedNetGreen, RbLedNetBlue, RbLedNetRed, RbLedNetYellow],
    FSettings.TrayLedTypeNet);
  { OnClick, not just user clicks: TCustomCheckBox.SetState (Vcl.StdCtrls)
    fires Click on every programmatic Checked assignment too. Loading
    Disk=False/Net=True straight into the two checkboxes would trip
    ChkLedDiskClick's "keep at least one on" guard against the *other*
    checkbox's still-stale value (False, mid-assignment) and silently flip
    Disk back to True. Detach the handlers for this pair of assignments. }
  ChkLedDisk.OnClick := nil;
  ChkLedNet.OnClick := nil;
  try
    ChkLedDisk.Checked := FSettings.TrayLedDisk;
    ChkLedNet.Checked := FSettings.TrayLedNet;
  finally
    ChkLedDisk.OnClick := ChkLedDiskClick;
    ChkLedNet.OnClick := ChkLedNetClick;
  end;
  ChkLedTotal.Checked := FSettings.TrayLedTotal;
  RbTrayOnly.Checked := FSettings.WindowHidden;
  RbWinTrayLed.Checked := (not FSettings.WindowHidden) and FSettings.TrayLed;
  RbWinOnly.Checked := (not FSettings.WindowHidden) and (not FSettings.TrayLed);
  RbScale100.Checked := FSettings.Scale = 100;
  RbScale150.Checked := FSettings.Scale = 150;
  RbScale200.Checked := FSettings.Scale = 200;
  RbScaleAuto.Checked := not (RbScale100.Checked or RbScale150.Checked or RbScale200.Checked);
  RebuildDriveList(FSettings.TrayLedDrives);
  ChkPingEnabled.Checked := FSettings.PingEnabled;
  ChkAutoGw.Checked := FSettings.PingAutoGateway;
  EdHost.Text := FSettings.PingHost;
  EdInterval.Text := IntToStr(FSettings.PingIntervalSec);
  EdFair.Text := IntToStr(FSettings.PingFairMs);
  EdSlow.Text := IntToStr(FSettings.PingSlowMs);
  EdTimeout.Text := IntToStr(FSettings.PingTimeoutMs);
  SyncPingControlsEnabled;
end;

function TOptionsForm.TryParseInt(const S: string; out AValue: Integer): Boolean;
var
  T: string;
begin
  T := Trim(S);
  Result := (T <> '') and TryStrToInt(T, AValue);
end;

procedure TOptionsForm.ShowValidationError(const AMessage: string);
begin
  MessageBox(Handle, PChar(AMessage), PChar(S('opt.title')), MB_OK or MB_ICONWARNING);
end;

function TOptionsForm.ValidateInputs(out AInterval, AFair, ASlow, ATimeout: Integer): Boolean;
begin
  Result := False;

  if not TryParseInt(EdInterval.Text, AInterval) then
  begin
    ShowValidationError(S('opt.err.interval_number'));
    if EdInterval.CanFocus then
      EdInterval.SetFocus;
    Exit;
  end;
  if AInterval < CMinIntervalSec then
  begin
    ShowValidationError(Format(S('opt.err.interval_min'), [CMinIntervalSec]));
    if EdInterval.CanFocus then
      EdInterval.SetFocus;
    Exit;
  end;

  if (not TryParseInt(EdFair.Text, AFair)) or
     (not TryParseInt(EdSlow.Text, ASlow)) or
     (not TryParseInt(EdTimeout.Text, ATimeout)) then
  begin
    ShowValidationError(S('opt.err.threshold_number'));
    if EdFair.CanFocus then
      EdFair.SetFocus;
    Exit;
  end;
  if (AFair < 1) or (ASlow < 1) or (ATimeout < 1) then
  begin
    ShowValidationError(S('opt.err.threshold_positive'));
    if EdFair.CanFocus then
      EdFair.SetFocus;
    Exit;
  end;
  if not ((AFair < ASlow) and (ASlow < ATimeout)) then
  begin
    ShowValidationError(S('opt.err.threshold_order'));
    if EdFair.CanFocus then
      EdFair.SetFocus;
    Exit;
  end;

  Result := True;
end;

procedure TOptionsForm.BtnOkClick(Sender: TObject);
var
  IntervalSec, FairMs, SlowMs, TimeoutMs: Integer;
begin
  if FSettings = nil then
  begin
    ModalResult := mrCancel;
    Exit;
  end;

  if ChkPingEnabled.Checked then
  begin
    if not ValidateInputs(IntervalSec, FairMs, SlowMs, TimeoutMs) then
      Exit;
  end
  else
  begin
    { Disabled Ping fields are not edited; keep last saved values. }
    IntervalSec := FSettings.PingIntervalSec;
    FairMs := FSettings.PingFairMs;
    SlowMs := FSettings.PingSlowMs;
    TimeoutMs := FSettings.PingTimeoutMs;
  end;

  FSettings.StayOnTop := ChkStayOnTop.Checked;
  case CbLanguage.ItemIndex of
    1:
      FSettings.Language := 'ja';
    2:
      FSettings.Language := 'en';
  else
    FSettings.Language := 'auto';
  end;
  if ChkStartup.Enabled then
    FSettings.Startup := ChkStartup.Checked;
  { When ChkStartup is disabled (Store build, blocked from outside) leave the
    saved preference alone and skip the registration call below. }
  { Hidden on Store builds (see LoadFromSettings): leave the saved preference
    untouched rather than write back a hidden checkbox's leftover state. }
  if not IsStorePackage then
    FSettings.UpdateEnabled := ChkUpdateCheck.Checked;
  if RbFps10.Checked then
    FSettings.Fps := 10
  else if RbFps20.Checked then
    FSettings.Fps := 20
  else
    FSettings.Fps := 15;
  if RbGraph2.Checked then
    FSettings.GraphRateHz := 2.0
  else if RbGraph05.Checked then
    FSettings.GraphRateHz := 0.5
  else
    FSettings.GraphRateHz := 1.0;
  if RbScaleLog.Checked then
    FSettings.SpeedScale := ssLog
  else
    FSettings.SpeedScale := ssLinear;
  FSettings.TrayLedType := CheckedLedColor(
    [RbLedDiskGreen, RbLedDiskBlue, RbLedDiskRed, RbLedDiskYellow]);
  FSettings.TrayLedTypeNet := CheckedLedColor(
    [RbLedNetGreen, RbLedNetBlue, RbLedNetRed, RbLedNetYellow]);
  { ChkLedDiskClick/ChkLedNetClick keep at least one checked; Normalize is
    just a backstop against the two ever both landing on False here. }
  FSettings.TrayLedDisk := ChkLedDisk.Checked;
  FSettings.TrayLedNet := ChkLedNet.Checked;
  FSettings.TrayLedTotal := ChkLedTotal.Checked;
  FSettings.TrayLedDrives := CheckedDrives;
  if RbTrayOnly.Checked then
  begin
    FSettings.WindowHidden := True;
    FSettings.TrayLed := True;
  end
  else
  begin
    FSettings.WindowHidden := False;
    FSettings.TrayLed := RbWinTrayLed.Checked;
  end;
  if RbScale100.Checked then
    FSettings.Scale := 100
  else if RbScale150.Checked then
    FSettings.Scale := 150
  else if RbScale200.Checked then
    FSettings.Scale := 200
  else
    FSettings.Scale := 0;
  FSettings.PingEnabled := ChkPingEnabled.Checked;
  FSettings.PingAutoGateway := ChkAutoGw.Checked;
  FSettings.PingHost := Trim(EdHost.Text);
  FSettings.PingIntervalSec := IntervalSec;
  FSettings.PingFairMs := FairMs;
  FSettings.PingSlowMs := SlowMs;
  FSettings.PingTimeoutMs := TimeoutMs;

  if ChkStartup.Enabled then
    try
      TStartup.SetRegistered(FSettings.Startup);
    except
      on E: Exception do
      begin
        MessageBox(Handle, PChar(E.Message), PChar(S('opt.title')), MB_OK or MB_ICONWARNING);
        Exit;
      end;
    end;

  ModalResult := mrOk;
end;

class function TOptionsForm.Execute(AOwner: TComponent; ASettings: TAppSettings;
  APresence: TDrivePresenceFunc): Boolean;
var
  Dlg: TOptionsForm;
begin
  Dlg := TOptionsForm.Create(AOwner);
  try
    Dlg.BindSettings(ASettings, APresence);
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
