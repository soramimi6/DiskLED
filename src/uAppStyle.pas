unit uAppStyle;

{ Activates one application-wide VCL style (the light or dark "Windows10"
  style bundled under styles/, matching the OS light/dark setting) once at
  startup, from DiskLED.dpr.

  This exists because a per-form TControl.StyleName override is meaningless
  on its own: VCL only ever consults a control's own StyleName once a
  custom style is active application-wide (TStyleManager.IsCustomStyleActive
  -- see StyleServices() and TControl.IsCustomStyleActive in Vcl.Themes.pas /
  Vcl.Controls.pas). Nothing in this project ever called
  TStyleManager.SetStyle/TrySetStyle before, so no per-form StyleName
  assignment (on the Options dialog or anywhere else) ever visibly did
  anything.

  Windows that paint themselves entirely (the main gadget window, the
  dashboard, the Ping result window) opt back out of this app-wide style by
  setting their own StyleName to the literal 'Windows' (VCL's built-in
  "no custom style" name) -- see uThemedHudForm.CreateWnd and
  uMainForm.FormCreate. A form with StyleName='Windows' renders with plain
  native/system chrome regardless of the app-wide style, and children that
  don't set their own StyleName inherit it from their parent form. }

interface

procedure ApplyAppStyle;

implementation

uses
  System.SysUtils,
  Vcl.Themes,
  Vcl.Styles,
  uDashboardTheme;

function LocateStyleFile(const AFileName: string): string;
var
  Base, Candidate: string;
  i: Integer;
begin
  Base := ExtractFilePath(ParamStr(0));
  for i := 0 to 5 do
  begin
    Candidate := IncludeTrailingPathDelimiter(Base) + 'styles\' + AFileName;
    if FileExists(Candidate) then
      Exit(Candidate);
    Base := ExpandFileName(IncludeTrailingPathDelimiter(Base) + '..');
  end;
  Result := '';
end;

{ Loads AFileName and returns the style name it registered under, without
  hardcoding that name: a .vsf file's internal name comes from whatever the
  VCL Style Designer named it when the file was authored, which need not
  match the filename. Comparing TStyleManager's StyleNames before/after the
  load finds whatever name actually appeared. }
function LoadStyleFileName(const AFileName: string): string;
var
  Path, N: string;
  Before: TArray<string>;
  WasThere: Boolean;
  B: string;
begin
  Result := '';
  Path := LocateStyleFile(AFileName);
  if Path = '' then
    Exit;
  Before := TStyleManager.StyleNames;
  try
    { Return value intentionally unused -- success/failure is determined
      below by whether a new name actually shows up in StyleNames. }
    TStyleManager.LoadFromFile(Path);
  except
    Exit;
  end;
  for N in TStyleManager.StyleNames do
  begin
    WasThere := False;
    for B in Before do
      if SameText(B, N) then
      begin
        WasThere := True;
        Break;
      end;
    if not WasThere then
      Exit(N);
  end;
end;

procedure ApplyAppStyle;
const
  CLightFileName = 'Windows10.vsf';
  CDarkFileName = 'Windows10Dark.vsf';
var
  TargetFile, TargetStyle: string;
begin
  if SystemUsesLightTheme then
    TargetFile := CLightFileName
  else
    TargetFile := CDarkFileName;

  TargetStyle := LoadStyleFileName(TargetFile);
  if (TargetStyle = '') and (TargetFile <> CLightFileName) then
    { Dark style file missing/unloadable -- fall back to light rather than
      leaving the whole app on the plain native style. }
    TargetStyle := LoadStyleFileName(CLightFileName);

  if TargetStyle <> '' then
    TStyleManager.TrySetStyle(TargetStyle, False);
end;

end.
