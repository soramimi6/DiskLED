unit uOptionsForm;

interface

uses
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  uSettings;

type
  TOptionsForm = class(TForm)
    PnlContent: TPanel;
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
    LblSecTrayLedSource: TLabel;
    RbLedGreen: TRadioButton;
    RbLedBlue: TRadioButton;
    RbLedRed: TRadioButton;
    PnlLedSource: TPanel;
    RbLedDisk: TRadioButton;
    RbLedNet: TRadioButton;
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
    procedure BtnResetThresholdsClick(Sender: TObject);
    procedure BtnOkClick(Sender: TObject);
  private
    FSettings: TAppSettings;
    procedure ApplyModernStyle;
    procedure ApplyCaptions;
    procedure LoadFromSettings;
    procedure SyncPingControlsEnabled;
    function TryParseInt(const S: string; out AValue: Integer): Boolean;
    function ValidateInputs(out AInterval, AFair, ASlow, ATimeout: Integer): Boolean;
    procedure ShowValidationError(const AMessage: string);
  public
    procedure BindSettings(ASettings: TAppSettings);
    class function Execute(AOwner: TComponent; ASettings: TAppSettings): Boolean; static;
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
  Vcl.Themes,
  Vcl.Styles,
  uAppStrings,
  uStartup,
  uPackaging,
  uMetricsTypes;

const
  CDefaultFairMs = 200;
  CDefaultSlowMs = 500;
  CDefaultTimeoutMs = 1000;
  CMinIntervalSec = 300;

procedure TOptionsForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW);
end;

function StyleIsAvailable(const AName: string): Boolean;
var
  N: string;
begin
  for N in TStyleManager.StyleNames do
    if SameText(N, AName) then
      Exit(True);
  Result := False;
end;

function LocateWindows10Style: string;
var
  Base, Candidate: string;
  i: Integer;
begin
  Base := ExtractFilePath(ParamStr(0));
  for i := 0 to 5 do
  begin
    Candidate := IncludeTrailingPathDelimiter(Base) + 'styles\Windows10.vsf';
    if FileExists(Candidate) then
      Exit(Candidate);
    Base := ExpandFileName(IncludeTrailingPathDelimiter(Base) + '..');
  end;
  Result := '';
end;

procedure TOptionsForm.FormCreate(Sender: TObject);
begin
  ApplyModernStyle;
  SyncPingControlsEnabled;
end;

procedure TOptionsForm.ApplyModernStyle;
const
  CStyleName = 'Windows10';
var
  Path: string;
begin
  { Per-form style only — MainForm stays unstyled (custom skin window). }
  if not StyleIsAvailable(CStyleName) then
  begin
    Path := LocateWindows10Style;
    if Path <> '' then
    try
      TStyleManager.LoadFromFile(Path);
    except
    end;
  end;
  if StyleIsAvailable(CStyleName) then
    StyleName := CStyleName;
end;

procedure TOptionsForm.BindSettings(ASettings: TAppSettings);
begin
  FSettings := ASettings;
  ApplyCaptions;
  LoadFromSettings;
end;

procedure TOptionsForm.ApplyCaptions;
begin
  Caption := S('opt.title');
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
  RbLedGreen.Caption := S('opt.tray_led_color_green');
  RbLedBlue.Caption := S('opt.tray_led_color_blue');
  RbLedRed.Caption := S('opt.tray_led_color_red');
  LblSecTrayLedSource.Caption := S('opt.tray_led_source');
  RbLedDisk.Caption := S('opt.tray_led_source_disk');
  RbLedNet.Caption := S('opt.tray_led_source_net');
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
  if SameText(FSettings.TrayLedType, 'blue') then
    RbLedBlue.Checked := True
  else if SameText(FSettings.TrayLedType, 'red') then
    RbLedRed.Checked := True
  else
    RbLedGreen.Checked := True;
  if SameText(FSettings.TrayLedSource, 'net') then
    RbLedNet.Checked := True
  else
    RbLedDisk.Checked := True;
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
  if RbLedBlue.Checked then
    FSettings.TrayLedType := 'blue'
  else if RbLedRed.Checked then
    FSettings.TrayLedType := 'red'
  else
    FSettings.TrayLedType := 'green';
  if RbLedNet.Checked then
    FSettings.TrayLedSource := 'net'
  else
    FSettings.TrayLedSource := 'disk';
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

class function TOptionsForm.Execute(AOwner: TComponent; ASettings: TAppSettings): Boolean;
var
  Dlg: TOptionsForm;
begin
  Dlg := TOptionsForm.Create(AOwner);
  try
    Dlg.BindSettings(ASettings);
    Result := Dlg.ShowModal = mrOk;
  finally
    Dlg.Free;
  end;
end;

end.
