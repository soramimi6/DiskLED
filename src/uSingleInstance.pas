unit uSingleInstance;

interface

type
  TSingleInstance = class
  public
    class function Acquire: Boolean; static;
    class procedure FocusExisting; static;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Messages;

const
  CMutexName = 'Local\DiskLED.3.SingleInstance';
  CWindowClass = 'DiskLEDMainWnd';

var
  GMutex: THandle = 0;

class function TSingleInstance.Acquire: Boolean;
begin
  GMutex := CreateMutex(nil, True, PChar(CMutexName));
  Result := (GMutex <> 0) and (GetLastError <> ERROR_ALREADY_EXISTS);
  if not Result and (GMutex <> 0) then
  begin
    CloseHandle(GMutex);
    GMutex := 0;
  end;
end;

class procedure TSingleInstance.FocusExisting;
var
  Wnd: HWND;
begin
  Wnd := FindWindow(CWindowClass, nil);
  if Wnd = 0 then
    Exit;
  if IsIconic(Wnd) then
    ShowWindow(Wnd, SW_RESTORE)
  else
    ShowWindow(Wnd, SW_SHOW);
  SetForegroundWindow(Wnd);
  SendMessage(Wnd, WM_NULL, 0, 0);
end;

initialization

finalization
  if GMutex <> 0 then
    CloseHandle(GMutex);

end.
