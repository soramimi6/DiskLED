program DiskLED;

uses
  Vcl.Forms,
  Winapi.Windows,
  uAppStrings in 'src\uAppStrings.pas',
  uSingleInstance in 'src\uSingleInstance.pas',
  uLayoutTypes in 'src\view\uLayoutTypes.pas',
  uSkinLoader in 'src\view\uSkinLoader.pas',
  uDisplayModes in 'src\view\uDisplayModes.pas',
  uAssetStore in 'src\view\uAssetStore.pas',
  uMeterRenderer in 'src\view\uMeterRenderer.pas',
  uDigitRenderer in 'src\view\uDigitRenderer.pas',
  uGraphRenderer in 'src\view\uGraphRenderer.pas',
  uMetricsTypes in 'src\metrics\uMetricsTypes.pas',
  uCpuCollector in 'src\metrics\uCpuCollector.pas',
  uGpuCollector in 'src\metrics\uGpuCollector.pas',
  uMemCollector in 'src\metrics\uMemCollector.pas',
  uDiskCollector in 'src\metrics\uDiskCollector.pas',
  uNetCollector in 'src\metrics\uNetCollector.pas',
  uIcmpApi in 'src\metrics\uIcmpApi.pas',
  uHostResolve in 'src\metrics\uHostResolve.pas',
  uPingCollector in 'src\metrics\uPingCollector.pas',
  uTracertCollector in 'src\metrics\uTracertCollector.pas',
  uAudioCollector in 'src\metrics\uAudioCollector.pas',
  uRangeEngine in 'src\metrics\uRangeEngine.pas',
  uHistoryBuffer in 'src\metrics\uHistoryBuffer.pas',
  uDashboardHistory in 'src\metrics\uDashboardHistory.pas',
  uCollector in 'src\metrics\uCollector.pas',
  uDisplayPipeline in 'src\metrics\uDisplayPipeline.pas',
  uWindowPlacement in 'src\uWindowPlacement.pas',
  uDpiScale in 'src\uDpiScale.pas',
  uSettings in 'src\uSettings.pas',
  uAppStyle in 'src\uAppStyle.pas',
  uStartup in 'src\uStartup.pas',
  uPackaging in 'src\uPackaging.pas',
  uUpdateCheck in 'src\uUpdateCheck.pas',
  uHoverTip in 'src\uHoverTip.pas',
  uOptionsForm in 'src\uOptionsForm.pas' {OptionsForm},
  uDashboardTheme in 'src\dashboard\uDashboardTheme.pas',
  uThemedHudForm in 'src\uThemedHudForm.pas',
  uTraceRouteForm in 'src\uTraceRouteForm.pas' {TraceRouteForm},
  uDashboardGraph in 'src\dashboard\uDashboardGraph.pas',
  uDashboardPainter in 'src\dashboard\uDashboardPainter.pas',
  uDashboardCard in 'src\dashboard\uDashboardCard.pas',
  uDashboardForm in 'src\dashboard\uDashboardForm.pas' {DashboardForm},
  uMainForm in 'src\uMainForm.pas' {MainForm};

{$R *.res}

begin
  if not TSingleInstance.Acquire then
  begin
    TSingleInstance.FocusExisting;
    Halt(0);
  end;

  { Language must be resolved before any form is created. FSettings.Load runs
    too late (inside Application.CreateForm), so read just the one key here. }
  InitAppLanguage(TAppSettings.ReadLanguagePref);
  Application.Initialize;
  Application.MainFormOnTaskbar := False;
  Application.ShowMainForm := True;
  Application.Title := 'DiskLED';
  { Must run before any form is created: a per-form StyleName override
    (used by uMainForm/uThemedHudForm to opt out, and implicitly by
    uOptionsForm to opt in) only has any effect once an app-wide custom
    style is active -- see uAppStyle's header comment. }
  ApplyAppStyle;
  { Strip APPWINDOW from Application before the main form is created. }
  SetWindowLong(Application.Handle, GWL_EXSTYLE,
    (GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW));
  ShowWindow(Application.Handle, SW_HIDE);
  Application.CreateForm(TMainForm, MainForm);
  ShowWindow(Application.Handle, SW_HIDE);
  Application.Run;
end.
