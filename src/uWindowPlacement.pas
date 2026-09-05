unit uWindowPlacement;

{ Multi-monitor aware clamp + edge snap for the borderless gadget. }

interface

uses
  Winapi.Windows,
  Winapi.MultiMon;

const
  CEdgeSnapPx = 16;

type
  { Grab origin for WM_MOVING. Snap must follow the mouse from click, not
    the last snapped rect — otherwise a message delta never exceeds SnapPx
    and the window sticks to the work-area edge (thin skins especially). }
  TGadgetDragState = record
    Active: Boolean;
    GrabMouse: TPoint;
    GrabLeft: Integer;
    GrabTop: Integer;
  end;

procedure ConstrainAndSnapRect(var R: TRect; ADpi: Integer = 96);
procedure ClampRectToWindowMonitor(var R: TRect; AWnd: HWND);
procedure BeginGadgetDrag(var State: TGadgetDragState; const ABounds: TRect);
procedure ApplyGadgetDragRect(const State: TGadgetDragState; var R: TRect;
  ADpi: Integer);
procedure EndGadgetDrag(var State: TGadgetDragState);

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

function WorkAreaForWindow(AWnd: HWND): TRect;
var
  Mon: HMONITOR;
  Info: TMonitorInfo;
begin
  Mon := 0;
  if AWnd <> 0 then
    Mon := MonitorFromWindow(AWnd, MONITOR_DEFAULTTONEAREST);
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if (Mon <> 0) and GetMonitorInfo(Mon, @Info) then
    Result := Info.rcWork
  else
    SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0);
end;

procedure ConstrainToWorkArea(var Left, Top: Integer; W, H: Integer;
  const Work: TRect);
begin
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
end;

procedure SnapToWorkAreaEdges(var Left, Top: Integer; W, H: Integer;
  const Work: TRect; SnapPx: Integer);
begin
  if SnapPx < 1 then
    Exit;
  if Abs(Left - Work.Left) <= SnapPx then
    Left := Work.Left;
  if Abs((Left + W) - Work.Right) <= SnapPx then
    Left := Work.Right - W;
  if Abs(Top - Work.Top) <= SnapPx then
    Top := Work.Top;
  if Abs((Top + H) - Work.Bottom) <= SnapPx then
    Top := Work.Bottom - H;
end;

procedure ApplyPlacement(var R: TRect; ADpi: Integer; ASnap: Boolean);
var
  Work: TRect;
  W, H: Integer;
  Left, Top: Integer;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then
    Exit;

  Work := WorkAreaForRect(R);
  Left := R.Left;
  Top := R.Top;
  ConstrainToWorkArea(Left, Top, W, H, Work);
  if ASnap then
    SnapToWorkAreaEdges(Left, Top, W, H, Work, ScalePx(CEdgeSnapPx, ADpi));

  R.Left := Left;
  R.Top := Top;
  R.Right := Left + W;
  R.Bottom := Top + H;
end;

procedure ConstrainAndSnapRect(var R: TRect; ADpi: Integer);
begin
  ApplyPlacement(R, ADpi, True);
end;

{ Clamp-only (no edge snap) against the monitor a given window is on, rather
  than whichever monitor the rect itself happens to intersect most — for a
  transient popup (hover tip) anchored near an edge, the naive candidate
  rect can straddle into a neighboring monitor and get clamped there
  instead of staying on the owner window's monitor. }
procedure ClampRectToWindowMonitor(var R: TRect; AWnd: HWND);
var
  Work: TRect;
  W, H, Left, Top: Integer;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then
    Exit;

  Work := WorkAreaForWindow(AWnd);
  Left := R.Left;
  Top := R.Top;
  ConstrainToWorkArea(Left, Top, W, H, Work);

  R.Left := Left;
  R.Top := Top;
  R.Right := Left + W;
  R.Bottom := Top + H;
end;

procedure BeginGadgetDrag(var State: TGadgetDragState; const ABounds: TRect);
begin
  State.GrabLeft := ABounds.Left;
  State.GrabTop := ABounds.Top;
  State.Active := GetCursorPos(State.GrabMouse);
end;

procedure ApplyGadgetDragRect(const State: TGadgetDragState; var R: TRect;
  ADpi: Integer);
var
  Mouse: TPoint;
  W, H: Integer;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then
    Exit;

  if State.Active and GetCursorPos(Mouse) then
  begin
    { Ideal position from the click, so snap/unsnap uses total mouse travel. }
    R.Left := State.GrabLeft + (Mouse.X - State.GrabMouse.X);
    R.Top := State.GrabTop + (Mouse.Y - State.GrabMouse.Y);
    R.Right := R.Left + W;
    R.Bottom := R.Top + H;
    ApplyPlacement(R, ADpi, True);
  end
  else
    { Keyboard / no cursor: keep on-screen only. Snap on mouse-up. }
    ApplyPlacement(R, ADpi, False);
end;

procedure EndGadgetDrag(var State: TGadgetDragState);
begin
  State.Active := False;
end;

end.
