unit uThemedHudForm;

{ Base form for the app's palette-drawn secondary windows (dashboard, Ping
  result). Carries the two things every such window must do and that were
  copy-pasted (and, in 3.1.1, half-copied) before:
    - reassert the DWM dark/light title bar on every handle (re)creation
    - follow a live Windows light/dark switch (WM_SETTINGCHANGE / ImmersiveColorSet)
  DPI is deliberately NOT handled here: the dashboard uses Scaled=False with a
  manual HudMetrics/WM_DPICHANGED pipeline, the Ping window uses Scaled=True and
  lets VCL scale. Each derived form keeps its own DPI approach. }

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Forms;

type
  TThemedHudForm = class(TForm)
  protected
    { Reapply the current palette to this form's controls and repaint. Called
      on a live light/dark switch. Override; base is a no-op. }
    procedure ApplyPalette; virtual;
    procedure CreateWnd; override;
    procedure WMSettingChange(var Message: TWMSettingChange); message WM_SETTINGCHANGE;
  end;

implementation

uses
  System.SysUtils,
  uDashboardTheme;

procedure TThemedHudForm.ApplyPalette;
begin
  { no-op }
end;

procedure TThemedHudForm.CreateWnd;
begin
  inherited;
  { This window paints itself entirely (its own palette, not a VCL style) --
    opt out of the app-wide custom style uAppStyle activates at startup so
    its native child controls (buttons, list views, ...) keep their plain
    look instead of being re-skinned. 'Windows' is VCL's built-in name for
    "no custom style"; children with no StyleName of their own inherit this
    from the form. }
  StyleName := 'Windows';
  ApplyHudTitleBar(Handle);
end;

procedure TThemedHudForm.WMSettingChange(var Message: TWMSettingChange);
begin
  inherited;
  if (Message.Section <> nil) and
    SameText(string(Message.Section), 'ImmersiveColorSet') then
    ApplyPalette;
end;

end.
