unit uHoverTip;

{ Tracked Win32 tooltip. Needed because the main window reports HTCAPTION
  for dragging, so VCL ShowHint never sees client mouse-move. }

interface

uses
  Winapi.Windows,
  Winapi.CommCtrl;

type
  THoverTip = class
  private
    FWnd: HWND;
    FOwner: HWND;
    FText: string;
    FVisible: Boolean;
    procedure EnsureWindow;
    procedure FillInfo(var Info: TToolInfo);
  public
    destructor Destroy; override;
    procedure SetOwner(AOwner: HWND);
    procedure ShowAtCursor(const AText: string);
    procedure Hide;
    procedure UpdateText(const AText: string);
    property Visible: Boolean read FVisible;
  end;

implementation

uses
  Winapi.Messages,
  uWindowPlacement;

destructor THoverTip.Destroy;
begin
  Hide;
  if FWnd <> 0 then
  begin
    DestroyWindow(FWnd);
    FWnd := 0;
  end;
  inherited;
end;

procedure THoverTip.EnsureWindow;
var
  Icc: TInitCommonControlsEx;
  Info: TToolInfo;
begin
  if FWnd <> 0 then
    Exit;

  FillChar(Icc, SizeOf(Icc), 0);
  Icc.dwSize := SizeOf(Icc);
  Icc.dwICC := ICC_WIN95_CLASSES;
  InitCommonControlsEx(Icc);

  FWnd := CreateWindowEx(WS_EX_TOPMOST, TOOLTIPS_CLASS, nil,
    WS_POPUP or TTS_NOPREFIX or TTS_ALWAYSTIP,
    Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT),
    Integer(CW_USEDEFAULT), Integer(CW_USEDEFAULT),
    0, 0, HInstance, nil);
  if FWnd = 0 then
    Exit;

  SetWindowPos(FWnd, HWND_TOPMOST, 0, 0, 0, 0,
    SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  SendMessage(FWnd, TTM_SETMAXTIPWIDTH, 0, 400);

  FillInfo(Info);
  SendMessage(FWnd, TTM_ADDTOOL, 0, LPARAM(@Info));
end;

procedure THoverTip.FillInfo(var Info: TToolInfo);
begin
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(TToolInfo);
  Info.uFlags := TTF_TRACK or TTF_ABSOLUTE or TTF_TRANSPARENT;
  Info.hwnd := FOwner;
  Info.uId := 1;
  Info.lpszText := PChar(FText);
end;

procedure THoverTip.SetOwner(AOwner: HWND);
begin
  if FOwner = AOwner then
    Exit;
  Hide;
  FOwner := AOwner;
  if FWnd <> 0 then
  begin
    DestroyWindow(FWnd);
    FWnd := 0;
  end;
end;

procedure THoverTip.ShowAtCursor(const AText: string);
var
  Info: TToolInfo;
  Pt: TPoint;
  WndRect, R: TRect;
  H: Integer;
begin
  FText := AText;
  EnsureWindow;
  if FWnd = 0 then
    Exit;

  FillInfo(Info);
  SendMessage(FWnd, TTM_UPDATETIPTEXT, 0, LPARAM(@Info));
  GetCursorPos(Pt);
  SendMessage(FWnd, TTM_TRACKPOSITION, 0, MakeLParam(Pt.X, Pt.Y + 18));
  SendMessage(FWnd, TTM_TRACKACTIVATE, WPARAM(True), LPARAM(@Info));
  { TTM_GETBUBBLESIZE isn't reliable for a plain (non-balloon) tracked
    tooltip before it's shown, so measure the real on-screen rect once
    activated and correct the position if it overflows the work area —
    the reposition is a single SetWindowPos, imperceptible in practice. }
  if GetWindowRect(FWnd, WndRect) and (WndRect.Right > WndRect.Left) then
  begin
    H := WndRect.Bottom - WndRect.Top;
    R := WndRect;
    { Clamp to the monitor the main gadget window is on, not whichever
      monitor this rect's own geometry happens to resolve to — otherwise a
      tip anchored near the gadget's monitor edge can be pulled onto a
      neighboring monitor even though the gadget itself never left its own. }
    ClampRectToWindowMonitor(R, FOwner);
    if PtInRect(R, Pt) then
    begin
      { Clamping (typically near the bottom edge) pulled the tip up over
        the cursor itself. A tip window covering the cursor steals hover
        tracking from the owner, which re-triggers this same show/hide path
        every tick — a flicker loop. Flip above the cursor instead, then
        re-clamp so it still can't overflow the top edge either. }
      R.Top := Pt.Y - 18 - H;
      R.Bottom := R.Top + H;
      R.Left := WndRect.Left;
      R.Right := WndRect.Right;
      ClampRectToWindowMonitor(R, FOwner);
    end;
    if (R.Left <> WndRect.Left) or (R.Top <> WndRect.Top) then
      SendMessage(FWnd, TTM_TRACKPOSITION, 0, MakeLParam(R.Left, R.Top));
  end;
  FVisible := True;
end;

procedure THoverTip.Hide;
var
  Info: TToolInfo;
begin
  if (FWnd = 0) or (not FVisible) then
  begin
    FVisible := False;
    Exit;
  end;
  FillInfo(Info);
  SendMessage(FWnd, TTM_TRACKACTIVATE, WPARAM(False), LPARAM(@Info));
  FVisible := False;
end;

procedure THoverTip.UpdateText(const AText: string);
var
  Info: TToolInfo;
begin
  if AText = FText then
    Exit;
  FText := AText;
  if (FWnd = 0) or (not FVisible) then
    Exit;
  FillInfo(Info);
  SendMessage(FWnd, TTM_UPDATETIPTEXT, 0, LPARAM(@Info));
end;

end.
