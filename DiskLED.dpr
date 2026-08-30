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
  uMemCollector in 'src\metrics\uMemCollector.pas',
  uDiskCollector in 'src\metrics\uDiskCollector.pas',
  uNetCollector in 'src\metrics\uNetCollector.pas',
  uPingCollector in 'src\metrics\uPingCollector.pas',
  uRangeEngine in 'src\metrics\uRangeEngine.pas',
  uHistoryBuffer in 'src\metrics\uHistoryBuffer.pas',
  uDashboardHistory in 'src\metrics\uDashboardHistory.pas',
  uCollector in 'src\metrics\uCollector.pas',
  uDisplayPipeline in 'src\metrics\uDisplayPipeline.pas',
  uWindowPlacement in 'src\uWindowPlacement.pas',
  uDpiScale in 'src\uDpiScale.pas',
  uSettings in 'src\uSettings.pas',
  uStartup in 'src\uStartup.pas',
  uHoverTip in 'src\uHoverTip.pas',
  uOptionsForm in 'src\uOptionsForm.pas' {OptionsForm},
  uDashboardTheme in 'src\dashboard\uDashboardTheme.pas',
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

  InitAppLanguage;
  Application.Initialize;
  Application.MainFormOnTaskbar := False;
  Application.ShowMainForm := True;
  Application.Title := 'DiskLED';
  { Strip APPWINDOW from Application before the main form is created. }
  SetWindowLong(Application.Handle, GWL_EXSTYLE,
    (GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW) and (not WS_EX_APPWINDOW));
  ShowWindow(Application.Handle, SW_HIDE);
  Application.CreateForm(TMainForm, MainForm);
  ShowWindow(Application.Handle, SW_HIDE);
  Application.Run;
end.
