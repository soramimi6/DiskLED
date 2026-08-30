unit uDpiScale;

{ Per-monitor DPI helpers for the borderless gadget (integer scale, no blur). }

interface

uses
  Winapi.Windows;

function IntegerDisplayScale(ADpi: Integer): Integer;
function SnapPixels(ADpi: Integer): Integer;
procedure LayoutClientSize(ALayoutW, ALayoutH, AScale: Integer;
  out AClientW, AClientH: Integer);
function MonitorDpiForWindow(AWnd: HWND): Integer;

implementation

function IntegerDisplayScale(ADpi: Integer): Integer;
begin
  if ADpi < 1 then
    ADpi := 96;
  Result := ADpi div 96;
  if Result < 1 then
    Result := 1;
end;

function SnapPixels(ADpi: Integer): Integer;
begin
  if ADpi < 1 then
    ADpi := 96;
  Result := MulDiv(16, ADpi, 96);
end;

procedure LayoutClientSize(ALayoutW, ALayoutH, AScale: Integer;
  out AClientW, AClientH: Integer);
begin
  if AScale < 1 then
    AScale := 1;
  AClientW := ALayoutW * AScale;
  AClientH := ALayoutH * AScale;
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
