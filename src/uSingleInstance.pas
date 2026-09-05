unit uSingleInstance;

interface

type
  TSingleInstance = class
  public
    class function Acquire: Boolean; static;
    class procedure FocusExisting; static;
    { Registered message asking the running instance to activate itself
      (foreground, or restore from tray size). Shared by name across
      processes: RegisterWindowMessage returns the same id everywhere. }
    class function ActivateMsg: Cardinal; static;
  end;

implementation

uses
  Winapi.Windows;

const
  CMutexName = 'Local\DiskLED.3.SingleInstance';
  CWindowClass = 'DiskLEDMainWnd';
  CActivateMsgName = 'DiskLED_ActivateRequest';

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

class function TSingleInstance.ActivateMsg: Cardinal;
begin
  Result := RegisterWindowMessage(CActivateMsgName);
end;

class procedure TSingleInstance.FocusExisting;
var
  Wnd: HWND;
  Pid: DWORD;
begin
  Wnd := FindWindow(CWindowClass, nil);
  if Wnd = 0 then
    Exit;
  { Let the running instance decide how to activate itself (plain foreground,
    or restore from tray size): a raw ShowWindow from this process would
    bypass that logic and just reveal the window as last laid out. But only
    this process (freshly launched by the user's own click) holds the
    foreground-activation privilege, so hand it to the running instance
    before asking it to call SetForegroundWindow on itself - otherwise
    Windows' focus-stealing prevention silently drops that call. }
  Pid := 0;
  GetWindowThreadProcessId(Wnd, Pid);
  if Pid <> 0 then
    AllowSetForegroundWindow(Pid);
  PostMessage(Wnd, ActivateMsg, 0, 0);
end;

initialization

finalization
  if GMutex <> 0 then
    CloseHandle(GMutex);

end.
