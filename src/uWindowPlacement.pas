unit uWindowPlacement;

{ Multi-monitor aware clamp + edge snap for the borderless gadget. }

interface

uses
  Winapi.Windows,
  Winapi.MultiMon;

const
  CEdgeSnapPx = 16;

procedure ConstrainAndSnapRect(var R: TRect; ADpi: Integer = 96);

implementation

uses
  uDpiScale;

function WorkAreaForRect(const R: TRect): TRect;
var
  Mon: HMONITOR;
  Info: TMonitorInfo;
begin
  Mon := MonitorFromRect(@R, MONITOR_DEFAULTTONEAREST);
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if (Mon <> 0) and GetMonitorInfo(Mon, @Info) then
    Result := Info.rcWork
  else
    SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0);
end;

procedure ConstrainAndSnapRect(var R: TRect; ADpi: Integer);
var
  Work: TRect;
  W, H: Integer;
  Left, Top: Integer;
  SnapPx: Integer;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then
    Exit;

  SnapPx := SnapPixels(ADpi);
  Work := WorkAreaForRect(R);
  Left := R.Left;
  Top := R.Top;

  if W >= (Work.Right - Work.Left) then
    Left := Work.Left
  else
  begin
    if Left < Work.Left then
      Left := Work.Left;
    if Left + W > Work.Right then
      Left := Work.Right - W;
  end;

  if H >= (Work.Bottom - Work.Top) then
    Top := Work.Top
  else
  begin
    if Top < Work.Top then
      Top := Work.Top;
    if Top + H > Work.Bottom then
      Top := Work.Bottom - H;
  end;

  if Abs(Left - Work.Left) <= SnapPx then
    Left := Work.Left;
  if Abs((Left + W) - Work.Right) <= SnapPx then
    Left := Work.Right - W;
  if Abs(Top - Work.Top) <= SnapPx then
    Top := Work.Top;
  if Abs((Top + H) - Work.Bottom) <= SnapPx then
    Top := Work.Bottom - H;

  R.Left := Left;
  R.Top := Top;
  R.Right := Left + W;
  R.Bottom := Top + H;
end;

end.
