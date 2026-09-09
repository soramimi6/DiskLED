unit uStartup;

{ Current-user startup registration (no admin).

  Non-packaged builds (GitHub installer / portable): a value under
  HKCU\...\CurrentVersion\Run.

  Packaged builds (MSIX / Microsoft Store): the WinRT
  Windows.ApplicationModel.StartupTask API. HKCU Run writes from inside an MSIX
  container are silently redirected into the package-private virtual registry and
  never reach the real user hive, so the OS logon path and Task Manager's
  Startup tab never see them (this was the 3.1.1 bug). The manifest declares a
  windows.startupTask extension (TaskId "DiskLEDStartupTask", Enabled="false");
  this unit flips it on/off at runtime.

  The branch is chosen at runtime via uPackaging.IsStorePackage, because the same
  exe ships both ways. Off Store, none of the WinRT code below is reached. }

interface

type
  TStartup = class
  public
    class function IsRegistered: Boolean; static;
    class procedure SetRegistered(AEnabled: Boolean); static;
    { Store build only: True when the startup task has been turned off from
      outside the app (Task Manager / Settings > Startup Apps) or by group
      policy. In that state RequestEnableAsync is a no-op, so the Options UI
      should disable the checkbox and point the user at Windows settings.
      Always False on non-packaged builds. }
    class function BlockedBySystem: Boolean; static;
    { Both answers from a single state read (one WinRT round-trip on Store,
      one registry read off Store). Prefer this where the caller needs both. }
    class procedure QueryState(out ARegistered, ABlockedBySystem: Boolean); static;
  end;

implementation

uses
  System.SysUtils,
  System.Win.Registry,
  Winapi.Windows,
  Winapi.WinRT,
  Winapi.CommonTypes,
  Winapi.ApplicationModel,
  Winapi.Foundation,
  uPackaging,
  uAppStrings;

const
  CRunKey = 'Software\Microsoft\Windows\CurrentVersion\Run';
  CValueName = 'DiskLED';
  { Must match <desktop:StartupTask TaskId="..."> in packaging/msix/AppxManifest.xml. }
  CTaskId = 'DiskLEDStartupTask';
  CStartupTaskClass = 'Windows.ApplicationModel.StartupTask';
  { GetAsync is a local, no-network call (package manager query); this is a
    generous ceiling to keep a genuine stall from freezing the UI for long. }
  CGetAsyncTimeoutMs = 1500;

var
  { Keeps a fire-and-forget RequestEnableAsync operation alive until it settles. }
  GPendingEnable: IInterface;
  { A disable was requested while GPendingEnable was still settling; applied by
    SettlePendingEnable once that operation completes (see StoreSetRegistered). }
  GPendingDisableRequested: Boolean = False;
  { RoInitialize is called once per process, not once per call. }
  GRoInited: Boolean = False;

{ ------------------------------------------------------------------ }
{  Non-packaged: HKCU\...\Run value                                  }
{ ------------------------------------------------------------------ }

function RunKeyRegistered: Boolean;
var
  Reg: TRegistry;
begin
  Result := False;
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly(CRunKey) then
      Result := Reg.ValueExists(CValueName);
  finally
    Reg.Free;
  end;
end;

procedure RunKeySetRegistered(AEnabled: Boolean);
var
  Reg: TRegistry;
begin
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(CRunKey, True) then
      raise Exception.Create('Cannot open HKCU Run key');
    if AEnabled then
      Reg.WriteString(CValueName, '"' + ParamStr(0) + '"')
    else if Reg.ValueExists(CValueName) then
      Reg.DeleteValue(CValueName);
  finally
    Reg.Free;
  end;
end;

{ ------------------------------------------------------------------ }
{  Packaged: WinRT Windows.ApplicationModel.StartupTask              }
{                                                                    }
{  The Delphi 13 RTL projects StartupTaskState and the               }
{  IAsyncOperation<StartupTaskState> result type, but not the        }
{  StartupTask runtime class or its interfaces, so the two below are  }
{  declared by hand. IIDs and vtable order are from the Windows SDK   }
{  windows.applicationmodel.h (StartupTaskContract 1.0).             }
{ ------------------------------------------------------------------ }

type
  IStartupTask = interface;

  // Windows.Foundation.AsyncOperationCompletedHandler`1<Windows.ApplicationModel.StartupTask>
  AsyncOperationCompletedHandler_1__IStartupTask = interface(IUnknown)
    ['{741F7697-2452-5C80-83C6-3B6F822B904C}']
    procedure Invoke(asyncInfo: IInspectable; asyncStatus: AsyncStatus); safecall;
  end;

  // Windows.Foundation.IAsyncOperation`1<Windows.ApplicationModel.StartupTask>
  IAsyncOperation_1__IStartupTask = interface(IInspectable)
    ['{CBEC7A4E-A046-5330-873D-0FCE228792FA}']
    procedure put_Completed(handler: AsyncOperationCompletedHandler_1__IStartupTask); safecall;
    function get_Completed: AsyncOperationCompletedHandler_1__IStartupTask; safecall;
    function GetResults: IStartupTask; safecall;
  end;

  // Windows.ApplicationModel.IStartupTask
  IStartupTask = interface(IInspectable)
    ['{F75C23C8-B5F2-4F6C-88DD-36CB1D599D17}']
    function RequestEnableAsync: IAsyncOperation_1__StartupTaskState; safecall;
    procedure Disable; safecall;
    function get_State: StartupTaskState; safecall;
    function get_TaskId: HSTRING; safecall;
    property State: StartupTaskState read get_State;
  end;

  // Windows.ApplicationModel.IStartupTaskStatics
  IStartupTaskStatics = interface(IInspectable)
    ['{EE5B60BD-A148-41A7-B26E-E8B88A1E62F8}']
    function GetForCurrentPackageAsync: IInspectable; safecall;
    function GetAsync(taskId: HSTRING): IAsyncOperation_1__IStartupTask; safecall;
  end;

var
  { RoGetActivationFactory result is stable for the process lifetime. }
  GStatics: IStartupTaskStatics;

function MakeHString(const S: string; out H: HSTRING): Boolean;
begin
  Result := WindowsCreateString(PWideChar(S), Length(S), H) = S_OK;
end;

{ Waits for a short WinRT async operation (GetAsync) to finish, pumping the
  message queue so the UI stays responsive. Not used for RequestEnableAsync,
  which is fire-and-forget (see StoreSetRegistered) so its first-run consent
  prompt is not suppressed by a blocked message loop.
  Returns True if the operation completed without error within the timeout. }
function PumpAwait(const AOp: IInterface; ATimeoutMs: Cardinal): Boolean;
var
  Info: IAsyncInfo;
  Deadline: UInt64;
  Msg: TMsg;
begin
  Result := False;
  if not Supports(AOp, IAsyncInfo, Info) then
    Exit;
  Deadline := GetTickCount64 + ATimeoutMs;
  while True do
  begin
    if Info.Status = AsyncStatus.Completed then
      Exit(True);
    if Info.Status in [AsyncStatus.Canceled, AsyncStatus.Error] then
      Exit(False);
    if GetTickCount64 > Deadline then
      Exit(False);
    while PeekMessage(Msg, 0, 0, 0, PM_REMOVE) do
    begin
      TranslateMessage(Msg);
      DispatchMessage(Msg);
    end;
    Sleep(15);
  end;
end;

function GetStartupTaskStatics: IStartupTaskStatics;
var
  ClassId: HSTRING;
  Factory: IInspectable;
begin
  if GStatics <> nil then
    Exit(GStatics);
  Result := nil;
  if not GRoInited then
  begin
    { S_FALSE if the STA is already inited (VCL calls OleInitialize),
      RPC_E_CHANGED_MODE if it was inited MTA. Either way the existing apartment
      is usable, so ignore the result -- just do not init more than once. }
    RoInitialize(RO_INIT_SINGLETHREADED);
    GRoInited := True;
  end;
  if not MakeHString(CStartupTaskClass, ClassId) then
    Exit;
  try
    if Succeeded(RoGetActivationFactory(ClassId, IStartupTaskStatics, Factory)) then
      Supports(Factory, IStartupTaskStatics, Result);
  finally
    WindowsDeleteString(ClassId);
  end;
  GStatics := Result;
end;

function GetStartupTask: IStartupTask;
var
  Statics: IStartupTaskStatics;
  TaskId: HSTRING;
  Op: IAsyncOperation_1__IStartupTask;
begin
  Result := nil;
  try
    Statics := GetStartupTaskStatics;
    if Statics = nil then
      Exit;
    if not MakeHString(CTaskId, TaskId) then
      Exit;
    try
      Op := Statics.GetAsync(TaskId);
    finally
      WindowsDeleteString(TaskId);
    end;
    if (Op <> nil) and PumpAwait(Op, CGetAsyncTimeoutMs) then
      Result := Op.GetResults;
  except
    Result := nil; // any WinRT failure -> treat as "no task"; callers default safely
  end;
end;

function PendingEnableInFlight: Boolean; forward;

{ If a previous RequestEnableAsync has settled (or there is none), applies a
  disable that was requested while it was still in flight (see
  StoreSetRegistered) instead of silently dropping it. Called from every read
  and write of the task state, so it self-corrects the next time Options is
  opened even if the user never clicks OK again. }
procedure SettlePendingEnable(const ATask: IStartupTask);
begin
  if PendingEnableInFlight then
    Exit; // still settling -- do not touch it (see StoreSetRegistered comment)
  GPendingEnable := nil;
  if GPendingDisableRequested then
  begin
    GPendingDisableRequested := False;
    if (ATask <> nil) and (ATask.State in [StartupTaskState.Enabled, StartupTaskState.EnabledByPolicy]) then
      ATask.Disable;
  end;
end;

function StoreTaskState(out AState: StartupTaskState): Boolean;
var
  Task: IStartupTask;
begin
  Result := False;
  AState := StartupTaskState.Disabled;
  Task := GetStartupTask;
  if Task = nil then
    Exit;
  SettlePendingEnable(Task);
  try
    AState := Task.State;
    Result := True;
  except
    Result := False;
  end;
end;

procedure StoreQuery(out ARegistered, ABlockedBySystem: Boolean);
var
  St: StartupTaskState;
  Have: Boolean;
begin
  Have := StoreTaskState(St);
  ARegistered := Have and (St in [StartupTaskState.Enabled, StartupTaskState.EnabledByPolicy]);
  ABlockedBySystem := Have and (St in [StartupTaskState.DisabledByUser, StartupTaskState.DisabledByPolicy]);
end;

function PendingEnableInFlight: Boolean;
var
  Info: IAsyncInfo;
begin
  Result := (GPendingEnable <> nil) and Supports(GPendingEnable, IAsyncInfo, Info)
    and (Info.Status = AsyncStatus.Started);
end;

procedure StoreSetRegistered(AEnabled: Boolean);
var
  Task: IStartupTask;
begin
  if AEnabled then
  begin
    if PendingEnableInFlight then
      Exit; // a RequestEnableAsync (possibly with consent prompt) is still settling
  end
  else if PendingEnableInFlight then
  begin
    { A previous enable is still settling (its consent prompt may still be on
      screen). Do not tear down that operation here -- WinRT would cancel it
      out from under the prompt. Remember the disable and let
      SettlePendingEnable apply it once the enable completes (the next state
      read, e.g. the next time Options opens), instead of dropping it. }
    GPendingDisableRequested := True;
    Exit;
  end;

  Task := GetStartupTask;
  if Task = nil then
    raise Exception.Create(S('opt.err.startup_task')); // WinRT call failed -- do not report success

  SettlePendingEnable(Task);

  if AEnabled then
  begin
    if Task.State in [StartupTaskState.Enabled, StartupTaskState.EnabledByPolicy,
      StartupTaskState.DisabledByUser, StartupTaskState.DisabledByPolicy] then
      Exit; // already on, or blocked from outside (BlockedBySystem surfaces it)
    { Fire and forget. RequestEnableAsync shows a first-run consent prompt (and,
      even without one, needs the calling thread's message loop running) —
      blocking on the result here suppresses it. Hold the operation in a module
      var so the WinRT runtime does not tear it down before it completes; the
      resulting state is read back the next time Options opens. }
    GPendingDisableRequested := False;
    GPendingEnable := Task.RequestEnableAsync;
  end
  else
  begin
    if Task.State in [StartupTaskState.Enabled, StartupTaskState.EnabledByPolicy] then
      Task.Disable;
  end;
end;

{ ------------------------------------------------------------------ }
{  Public API                                                        }
{ ------------------------------------------------------------------ }

class function TStartup.IsRegistered: Boolean;
var
  Reg, Blocked: Boolean;
begin
  if IsStorePackage then
  begin
    StoreQuery(Reg, Blocked);
    Result := Reg;
  end
  else
    Result := RunKeyRegistered;
end;

class procedure TStartup.SetRegistered(AEnabled: Boolean);
begin
  if IsStorePackage then
    StoreSetRegistered(AEnabled)
  else
    RunKeySetRegistered(AEnabled);
end;

class function TStartup.BlockedBySystem: Boolean;
var
  Reg, Blocked: Boolean;
begin
  Result := False;
  if not IsStorePackage then
    Exit;
  StoreQuery(Reg, Blocked);
  Result := Blocked;
end;

class procedure TStartup.QueryState(out ARegistered, ABlockedBySystem: Boolean);
begin
  if IsStorePackage then
    StoreQuery(ARegistered, ABlockedBySystem)
  else
  begin
    ARegistered := RunKeyRegistered;
    ABlockedBySystem := False;
  end;
end;

end.
