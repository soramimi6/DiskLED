unit uDpiScale;

{ Per-monitor DPI helpers. Gadget uses 0.5-step scale (100/150/200…).
  Dashboard uses exact Dpi/96. Options stay on VCL Scaled. }

interface

uses
  Winapi.Windows;

function GadgetScale100(ADpi: Integer): Integer;
function MonitorEffectiveDpiForWindow(AWnd: HWND): Integer;
function DashboardScale(ADpi: Integer): Double;
function ScalePx(AValue, ADpi: Integer): Integer;
function DipFromPx(APx, ADpi: Integer): Integer;
function SnapPixels(ADpi: Integer): Integer;
procedure LayoutClientSize(ALayoutW, ALayoutH, AScale100: Integer;
  out AClientW, AClientH: Integer);
function MonitorDpiForWindow(AWnd: HWND): Integer;

implementation

uses
  Winapi.MultiMon,
  Winapi.ShellScaling;

function GadgetScale100(ADpi: Integer): Integer;
var
  HalfSteps: Integer;
begin
  { Round half-up to 0.5 steps. 125% (120dpi) → 150, not 100.
    Delphi Round() is bankers' rounding and would map 2.5 → 2. }
  if ADpi < 1 then
    ADpi := 96;
  HalfSteps := (ADpi * 2 + 48) div 96;
  if HalfSteps < 2 then
    HalfSteps := 2;
  Result := HalfSteps * 50;
end;

function MonitorEffectiveDpiForWindow(AWnd: HWND): Integer;
var
  Mon: HMONITOR;
  DpiX, DpiY: UINT;
begin
  { The monitor's live effective DPI, independent of any per-window DPI
    context. A poll needs this because a stationary window's own DPI context
    can lag a Settings scale change until it is notified. }
  Result := 0;
  if AWnd <> 0 then
  begin
    Mon := MonitorFromWindow(AWnd, MONITOR_DEFAULTTONEAREST);
    if (Mon <> 0) and
      (GetDpiForMonitor(Mon, MDT_EFFECTIVE_DPI, DpiX, DpiY) = S_OK) then
      Result := Integer(DpiX);
  end;
  if Result < 1 then
    Result := MonitorDpiForWindow(AWnd);
end;

function DashboardScale(ADpi: Integer): Double;
begin
  if ADpi < 1 then
    ADpi := 96;
  Result := ADpi / 96.0;
end;

function ScalePx(AValue, ADpi: Integer): Integer;
begin
  if ADpi < 1 then
    ADpi := 96;
  Result := MulDiv(AValue, ADpi, 96);
  if (AValue > 0) and (Result < 1) then
    Result := 1;
end;

function DipFromPx(APx, ADpi: Integer): Integer;
begin
  if ADpi < 1 then
    ADpi := 96;
  Result := MulDiv(APx, 96, ADpi);
end;

function SnapPixels(ADpi: Integer): Integer;
begin
  Result := ScalePx(16, ADpi);
end;

procedure LayoutClientSize(ALayoutW, ALayoutH, AScale100: Integer;
  out AClientW, AClientH: Integer);
begin
  if AScale100 < 100 then
    AScale100 := 100;
  AClientW := MulDiv(ALayoutW, AScale100, 100);
  AClientH := MulDiv(ALayoutH, AScale100, 100);
end;

function MonitorDpiForWindow(AWnd: HWND): Integer;
var
  DC: HDC;
begin
  Result := 0;
  if AWnd <> 0 then
    Result := GetDpiForWindow(AWnd);
  if Result > 0 then
    Exit;
  if AWnd <> 0 then
    DC := GetDC(AWnd)
  else
    DC := GetDC(0);
  try
    Result := GetDeviceCaps(DC, LOGPIXELSX);
  finally
    if AWnd <> 0 then
      ReleaseDC(AWnd, DC)
    else
      ReleaseDC(0, DC);
  end;
  if Result < 1 then
    Result := 96;
end;

end.
