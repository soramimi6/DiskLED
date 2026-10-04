unit uProcessCollector;

{ Per-resource TOP5 processes for the dashboard's process page, via PDH
  "\Process V2(*)\...". Process V2 covers every process without elevation (the
  OpenProcess route reaches only about half of them); its instance names are
  "name:pid", unique per process.

  Same-named processes (chrome, svchost, ...) are summed into one row and ranked
  by that sum. Sampling runs on a worker thread every 3/5/10 s (SetInterval) --
  one cycle over ~500 instances costs ~15 ms of PDH work -- and only while the
  process page is shown (SetActive). While inactive the PDH query is closed and
  the thread sleeps on its event, so the overview page costs nothing.

  Each listed row also carries its executable's path and version strings,
  read on the worker (file I/O) and cached by name. Icons are built from the
  path on the UI thread by TProcessIconCache. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections;

const
  { Rows kept per resource. The page shows the first 5 or more of them,
    depending on how tall the dashboard is (ProcessRowSlots). }
  CProcessTopMax = 20;

type
  TProcessResource = (prCpu, prMem, prIo);

  { PDH counters sampled per process (all from "\Process V2(*)"). }
  TProcessCounter = (pcCpu, pcMem, pcIoRead, pcIoWrite, pcCommit, pcHandles,
    pcThreads);

  { Per-process facts that need the process opened (token, bitness, image
    path) or its executable read (version strings). Cached by name. }
  TProcessDetail = record
    Path: string;
    Description: string;
    Company: string;
    Version: string;
    ProductName: string;
    Copyright: string;
    { Token could be queried; UserName / Elevated are meaningful only then. }
    HasToken: Boolean;
    UserName: string;
    Elevated: Boolean;
    { IsWow64Process answered; Is32Bit is meaningful only then. }
    HasBitness: Boolean;
    Is32Bit: Boolean;
  end;

  TProcessTopEntry = record
    Name: string;
    { Instances summed into this row, and their PIDs. }
    Count: Integer;
    Pids: TArray<Cardinal>;
    { One PID of this name, for the details and icon. 0 when unknown. }
    Pid: Cardinal;
    { % Processor Time: one fully busy core = 100, so it can exceed 100. }
    CpuPct: Double;
    { Working Set - Private, matching Task Manager's memory column. }
    MemBytes: UInt64;
    { All I/O (file, network, device), not disk only. }
    IoReadBps: Double;
    IoWriteBps: Double;
    { Private Bytes (commit charge), handle and thread counts, summed. }
    CommitBytes: UInt64;
    Handles: Int64;
    Threads: Int64;
    { Title of the first visible top-level window among Pids; '' if none. }
    WindowTitle: string;
    { True when the representative process could be opened (non-elevated, about
      half of all processes can't). Detail is only meaningful then. }
    HasDetail: Boolean;
    Detail: TProcessDetail;
  end;

  TProcessTop = record
    { False until the first sample after SetActive(True). }
    Valid: Boolean;
    Items: array[TProcessResource] of TArray<TProcessTopEntry>;
  end;

  TProcessCollector = class
  private
    FThread: TThread;
    FLock: TCriticalSection;
    FWake: TEvent;
    FStop: Boolean;
    FActive: Boolean;
    FPaused: Boolean;
    FIntervalMs: Cardinal;
    FTop: TProcessTop;
    { Worker-thread only. }
    FQuery: THandle;
    FCounters: array[TProcessCounter] of THandle;
    FBufs: array[TProcessCounter] of TBytes;
    FFailCount: Integer;
    { Lower-cased process name -> details. Successful lookups only, so a
      process that couldn't be opened is retried later (with whichever PID
      represents the name then). }
    FDetails: TDictionary<string, TProcessDetail>;
    procedure WorkerExecute;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SamplePdh(out ATop: TProcessTop): Boolean;
    procedure FillDetails(var AEntries: TArray<TProcessTopEntry>;
      ATitles: TDictionary<Cardinal, string>);
  public
    constructor Create;
    destructor Destroy; override;
    { True while the process page is shown. False also discards the last
      result, so the next activation starts from "no data" rather than
      showing a stale list. }
    procedure SetActive(AActive: Boolean);
    { Sampling period in seconds. Rate counters average over the period, so a
      longer one also smooths the values. }
    procedure SetInterval(ASec: Integer);
    { Freezes the last result: no sampling (PDH query closed) while paused,
      but unlike SetActive(False) the result is kept for display. Resuming
      starts afresh, first values about a second later. }
    procedure SetPaused(APaused: Boolean);
    procedure CopyTop(out ATop: TProcessTop);
  end;

  { Icons for the process page, keyed by image path and pixel size. UI thread
    only (shell calls). Owns every icon it returns. }
  TProcessIconCache = class
  private
    { Key: lower-cased path + '|' + size; '' path is the stock icon. }
    FIcons: TDictionary<string, THandle>;
    function LoadSized(const AFile: string; AIndex, ASize: Integer): THandle;
    function StockIcon(ASize: Integer): THandle;
  public
    constructor Create;
    destructor Destroy; override;
    { Icon of the executable at APath at ASize pixels, or the stock
      application icon when APath is empty or carries no icon. Returns an
      HICON (0 only if even the stock icon is unavailable). }
    function IconFor(const APath: string; ASize: Integer): THandle;
  end;

implementation

uses
  System.Generics.Defaults,
  Winapi.Windows;

const
  PDH_FMT_DOUBLE = $00000200;
  PDH_FMT_LARGE = $00000400;
  { pdh.h: without it formatted values are clipped to 100, which would cap a
    process using several cores at "one core". }
  PDH_FMT_NOCAP100 = $00008000;
  PDH_MORE_DATA = $800007D2;
  PDH_CSTATUS_VALID_DATA = $00000000;
  PDH_CSTATUS_NEW_DATA = $00000001;
  CCounterPaths: array[TProcessCounter] of string = (
    '\Process V2(*)\% Processor Time',
    '\Process V2(*)\Working Set - Private',
    '\Process V2(*)\IO Read Bytes/sec',
    '\Process V2(*)\IO Write Bytes/sec',
    '\Process V2(*)\Private Bytes',
    '\Process V2(*)\Handle Count',
    '\Process V2(*)\Thread Count');
  CCounterFormats: array[TProcessCounter] of DWORD = (
    PDH_FMT_DOUBLE or PDH_FMT_NOCAP100,
    PDH_FMT_LARGE,
    PDH_FMT_DOUBLE,
    PDH_FMT_DOUBLE,
    PDH_FMT_LARGE,
    PDH_FMT_LARGE,
    PDH_FMT_LARGE);
  CDefaultIntervalMs = 3000;
  CFirstSampleMs = 1000;
  { Same policy as uGpuCollector: re-initialise after repeated failures, and
    retry a failed init this often while the page stays open. }
  CRetryIntervalMs = 30000;
  CMaxFailsBeforeRetry = 3;
  CMaxBufGrowAttempts = 3;

type
  TPdhFmtCounterValue = record
    CStatus: LongWord;
    case Integer of
      0: (LongValue: Int32);
      1: (DoubleValue: Double);
      2: (LargeValue: Int64);
      3: (WideStringValue: PWideChar);
  end;

  TPdhFmtCounterValueItemW = record
    szName: PWideChar;
    FmtValue: TPdhFmtCounterValue;
  end;
  PPdhFmtCounterValueItemW = ^TPdhFmtCounterValueItemW;

function PdhOpenQueryW(szDataSource: PWideChar; dwUserData: NativeUInt;
  var phQuery: THandle): LongInt; stdcall; external 'pdh.dll' name 'PdhOpenQueryW';
function PdhCloseQuery(hQuery: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhCloseQuery';
function PdhAddEnglishCounterW(hQuery: THandle; szFullCounterPath: PWideChar;
  dwUserData: NativeUInt; var phCounter: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhAddEnglishCounterW';
function PdhCollectQueryData(hQuery: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhCollectQueryData';
function PdhGetFormattedCounterArrayW(hCounter: THandle; dwFormat: DWORD;
  var lpdwBufferSize: DWORD; var lpdwItemCount: DWORD;
  ItemBuffer: PPdhFmtCounterValueItemW): LongInt; stdcall;
  external 'pdh.dll' name 'PdhGetFormattedCounterArrayW';

const
  PROCESS_QUERY_LIMITED_INFORMATION_ = $1000;
  SIID_APPLICATION_ = 2;
  SHGSI_ICONLOCATION_ = 0;
  { Details are cached by name; drop the cache wholesale past this many names
    so a long session churning through short-lived processes stays bounded. }
  CMaxDetailCache = 512;

type
  TStockIconInfo = record
    cbSize: DWORD;
    hIcon: HICON;
    iSysImageIndex: Integer;
    iIcon: Integer;
    szPath: array[0..MAX_PATH - 1] of WideChar;
  end;

function QueryFullProcessImageNameW_(hProcess: THandle; dwFlags: DWORD;
  lpExeName: PWideChar; var lpdwSize: DWORD): BOOL; stdcall;
  external kernel32 name 'QueryFullProcessImageNameW';
function SHGetStockIconInfo_(siid: Integer; uFlags: UINT;
  var psii: TStockIconInfo): HRESULT; stdcall;
  external 'shell32.dll' name 'SHGetStockIconInfo';
{ Extracts icon AIndex of a file at an exact pixel size (low word of
  nIconSize), unlike SHGetFileInfo's fixed 16/32 px. }
function SHDefExtractIconW_(pszIconFile: PWideChar; iIndex: Integer;
  uFlags: UINT; phiconLarge, phiconSmall: Pointer; nIconSize: UINT): HRESULT;
  stdcall; external 'shell32.dll' name 'SHDefExtractIconW';

function IsWow64Process_(hProcess: THandle; var Wow64Process: BOOL): BOOL; stdcall;
  external kernel32 name 'IsWow64Process';

{ "user" (no domain) of the token's owner SID, and whether it is elevated. }
procedure ReadTokenInfo(AProcess: THandle; var ADetail: TProcessDetail);
type
  TTokenElevation_ = record
    TokenIsElevated: DWORD;
  end;
const
  TokenElevation_ = TTokenInformationClass(20);
var
  Token: THandle;
  Buf: array[0..511] of Byte;
  Len, NameLen, DomLen: DWORD;
  Use: SID_NAME_USE;
  Name, Dom: array[0..255] of WideChar;
  Elev: TTokenElevation_;
begin
  if not OpenProcessToken(AProcess, TOKEN_QUERY, Token) then
    Exit;
  try
    Len := 0;
    if GetTokenInformation(Token, TokenUser, @Buf[0], SizeOf(Buf), Len) then
    begin
      NameLen := Length(Name);
      DomLen := Length(Dom);
      if LookupAccountSidW(nil, PSIDAndAttributes(@Buf[0]).Sid, @Name[0], NameLen,
        @Dom[0], DomLen, Use) then
      begin
        ADetail.UserName := Name;
        ADetail.HasToken := True;
      end;
    end;
    Len := 0;
    if GetTokenInformation(Token, TokenElevation_, @Elev, SizeOf(Elev), Len) then
      ADetail.Elevated := Elev.TokenIsElevated <> 0;
  finally
    CloseHandle(Token);
  end;
end;

{ Opens APid once for its image path, token user / elevation and bitness.
  False when the process can't be opened or its path can't be read. }
function ReadProcessInfo(APid: Cardinal; var ADetail: TProcessDetail): Boolean;
var
  H: THandle;
  Buf: array[0..32767] of WideChar;
  Len: DWORD;
  Wow: BOOL;
begin
  Result := False;
  if APid = 0 then
    Exit;
  H := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION_, False, APid);
  if H = 0 then
    Exit;
  try
    Len := Length(Buf);
    if not QueryFullProcessImageNameW_(H, 0, @Buf[0], Len) or (Len = 0) then
      Exit;
    SetString(ADetail.Path, PWideChar(@Buf[0]), Len);
    ReadTokenInfo(H, ADetail);
    Wow := False;
    if IsWow64Process_(H, Wow) then
    begin
      { DiskLED is 64-bit, so the OS is too: WOW64 means a 32-bit process. }
      ADetail.HasBitness := True;
      ADetail.Is32Bit := Wow;
    end;
    Result := True;
  finally
    CloseHandle(H);
  end;
end;

type
  TWindowTitleScan = record
    Titles: TDictionary<Cardinal, string>;
    SelfPid: Cardinal;
  end;
  PWindowTitleScan = ^TWindowTitleScan;

function CollectWindowTitle(AWnd: HWND; AParam: LPARAM): BOOL; stdcall;
var
  Scan: PWindowTitleScan;
  Pid: DWORD;
  Buf: array[0..511] of WideChar;
  N: Integer;
begin
  Result := True;
  Scan := PWindowTitleScan(AParam);
  if not IsWindowVisible(AWnd) or (GetWindow(AWnd, GW_OWNER) <> 0) then
    Exit;
  if (GetWindowLong(AWnd, GWL_EXSTYLE) and WS_EX_TOOLWINDOW) <> 0 then
    Exit;
  Pid := 0;
  GetWindowThreadProcessId(AWnd, Pid);
  { GetWindowText on our own windows sends WM_GETTEXT to the UI thread, which
    may itself be waiting for this worker to finish -- skip them. Other
    processes' titles are read without messaging. }
  if (Pid = 0) or (Pid = Scan.SelfPid) or Scan.Titles.ContainsKey(Pid) then
    Exit;
  N := GetWindowTextW(AWnd, @Buf[0], Length(Buf));
  if N > 0 then
    Scan.Titles.Add(Pid, Trim(Copy(string(PWideChar(@Buf[0])), 1, N)));
end;

{ PID -> title of its first visible, unowned, non-tool top-level window
  (EnumWindows runs in z-order, so that is usually the frontmost one). }
function BuildWindowTitles: TDictionary<Cardinal, string>;
var
  Scan: TWindowTitleScan;
begin
  Result := TDictionary<Cardinal, string>.Create;
  Scan.Titles := Result;
  Scan.SelfPid := GetCurrentProcessId;
  EnumWindows(@CollectWindowTitle, LPARAM(@Scan));
end;

{ Version strings from the file's version resource, in the first language it
  declares (then US English / Japanese Unicode as fallbacks for files without
  a translation table). }
procedure ReadVersionStrings(const APath: string; var ADetail: TProcessDetail);
var
  Size, Dummy, Len: DWORD;
  Data: TBytes;
  Trans: PDWORD;
  Langs: array[0..2] of string;
  Lang: string;

  function Query(const AKey: string): string;
  var
    P: PWideChar;
    L: UINT;
    i: Integer;
  begin
    Result := '';
    for i := 0 to High(Langs) do
    begin
      if Langs[i] = '' then
        Continue;
      if VerQueryValueW(@Data[0], PWideChar('\StringFileInfo\' + Langs[i] + '\' + AKey),
        Pointer(P), L) and (L > 0) then
      begin
        Result := Trim(string(P));
        if Result <> '' then
          Exit;
      end;
    end;
  end;

begin
  Dummy := 0;
  Size := GetFileVersionInfoSizeW(PWideChar(APath), Dummy);
  if Size = 0 then
    Exit;
  SetLength(Data, Size);
  if not GetFileVersionInfoW(PWideChar(APath), 0, Size, @Data[0]) then
    Exit;
  Lang := '';
  if VerQueryValueW(@Data[0], '\VarFileInfo\Translation', Pointer(Trans), Len) and
    (Len >= SizeOf(DWORD)) then
    Lang := IntToHex(LoWord(Trans^), 4) + IntToHex(HiWord(Trans^), 4);
  Langs[0] := Lang;
  Langs[1] := '040904B0';
  Langs[2] := '041104B0';
  ADetail.Description := Query('FileDescription');
  ADetail.Company := Query('CompanyName');
  ADetail.Version := Query('FileVersion');
  ADetail.ProductName := Query('ProductName');
  ADetail.Copyright := Query('LegalCopyright');
end;

type
  TProcessWorker = class(TThread)
  private
    FOwner: TProcessCollector;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TProcessCollector);
  end;

  TProcessAgg = record
    Name: string;
    Count: Integer;
    Pid: Cardinal;
    Pids: TArray<Cardinal>;
    Vals: array[TProcessCounter] of Double;
  end;

constructor TProcessWorker.Create(AOwner: TProcessCollector);
begin
  FOwner := AOwner;
  inherited Create(False);
  FreeOnTerminate := False;
end;

procedure TProcessWorker.Execute;
begin
  FOwner.WorkerExecute;
end;

{ "chrome:1234" -> name "chrome", pid 1234. Splits on the last ':' since the
  name part itself is not guaranteed colon-free. }
function SplitInstance(const AInstance: string; out AName: string;
  out APid: Cardinal): Boolean;
var
  P: Integer;
  V: Integer;
begin
  AName := AInstance;
  APid := 0;
  P := LastDelimiter(':', AInstance);
  if P > 0 then
  begin
    AName := Copy(AInstance, 1, P - 1);
    if TryStrToInt(Copy(AInstance, P + 1, MaxInt), V) and (V >= 0) then
      APid := Cardinal(V);
  end;
  Result := (AName <> '') and not SameText(AName, '_Total') and
    not SameText(AName, 'Idle');
end;

{ Fetches one wildcard counter's formatted array into ABuf. AItems points into
  ABuf, so it stays valid until the next call with the same buffer. }
function FetchArray(ACounter: THandle; AFormat: DWORD; var ABuf: TBytes;
  out AItems: PPdhFmtCounterValueItemW; out ACount: DWORD): Boolean;
var
  BufSize: DWORD;
  St: LongInt;
  Attempt: Integer;
begin
  BufSize := DWORD(Length(ABuf));
  ACount := 0;
  if Length(ABuf) > 0 then
    AItems := PPdhFmtCounterValueItemW(@ABuf[0])
  else
    AItems := nil;
  St := PdhGetFormattedCounterArrayW(ACounter, AFormat, BufSize, ACount, AItems);
  Attempt := 0;
  while (DWORD(St) = PDH_MORE_DATA) and (Attempt < CMaxBufGrowAttempts) do
  begin
    Inc(Attempt);
    { Processes start between the sizing call and the retry; pad for that. }
    SetLength(ABuf, Integer(BufSize) + Integer(BufSize) div 4 + 256);
    BufSize := DWORD(Length(ABuf));
    AItems := PPdhFmtCounterValueItemW(@ABuf[0]);
    St := PdhGetFormattedCounterArrayW(ACounter, AFormat, BufSize, ACount, AItems);
  end;
  Result := (St = 0) and (AItems <> nil);
end;

function ItemAt(AItems: PPdhFmtCounterValueItemW; AIndex: Integer): PPdhFmtCounterValueItemW;
begin
  Result := PPdhFmtCounterValueItemW(PByte(AItems) +
    AIndex * SizeOf(TPdhFmtCounterValueItemW));
end;

function ItemValid(AItem: PPdhFmtCounterValueItemW): Boolean;
begin
  Result := (AItem.szName <> nil) and
    ((AItem.FmtValue.CStatus = PDH_CSTATUS_VALID_DATA) or
     (AItem.FmtValue.CStatus = PDH_CSTATUS_NEW_DATA));
end;

type
  TRankItem = record
    Idx: Integer;
    Key: Double;
    Name: string;
  end;

{ Highest CProcessTopMax rows of AAggs[0..ACount-1] by one resource. Rows
  with a zero value are left out: an idle row says nothing about who is using
  the resource. Ties fall back to the name so the order doesn't jitter. }
function TopBy(const AAggs: TArray<TProcessAgg>; ACount: Integer;
  ARes: TProcessResource): TArray<TProcessTopEntry>;
var
  Rank: TArray<TRankItem>;
  i, N: Integer;
  Src: TProcessAgg;
begin
  SetLength(Rank, ACount);
  for i := 0 to ACount - 1 do
  begin
    Rank[i].Idx := i;
    Rank[i].Name := AAggs[i].Name;
    case ARes of
      prCpu: Rank[i].Key := AAggs[i].Vals[pcCpu];
      prMem: Rank[i].Key := AAggs[i].Vals[pcMem];
    else
      Rank[i].Key := AAggs[i].Vals[pcIoRead] + AAggs[i].Vals[pcIoWrite];
    end;
  end;
  TArray.Sort<TRankItem>(Rank, TComparer<TRankItem>.Construct(
    function(const L, R: TRankItem): Integer
    begin
      if L.Key > R.Key then
        Result := -1
      else if L.Key < R.Key then
        Result := 1
      else
        Result := CompareText(L.Name, R.Name);
    end));
  SetLength(Result, CProcessTopMax);
  N := 0;
  for i := 0 to ACount - 1 do
  begin
    if (N >= CProcessTopMax) or (Rank[i].Key <= 0) then
      Break;
    Src := AAggs[Rank[i].Idx];
    Result[N].Name := Src.Name;
    Result[N].Count := Src.Count;
    Result[N].Pid := Src.Pid;
    Result[N].Pids := Src.Pids;
    Result[N].CpuPct := Src.Vals[pcCpu];
    Result[N].MemBytes := UInt64(Round(Src.Vals[pcMem]));
    Result[N].IoReadBps := Src.Vals[pcIoRead];
    Result[N].IoWriteBps := Src.Vals[pcIoWrite];
    Result[N].CommitBytes := UInt64(Round(Src.Vals[pcCommit]));
    Result[N].Handles := Round(Src.Vals[pcHandles]);
    Result[N].Threads := Round(Src.Vals[pcThreads]);
    Inc(N);
  end;
  SetLength(Result, N);
end;

constructor TProcessCollector.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  FIntervalMs := CDefaultIntervalMs;
  FDetails := TDictionary<string, TProcessDetail>.Create;
  FThread := TProcessWorker.Create(Self);
end;

destructor TProcessCollector.Destroy;
begin
  FLock.Enter;
  try
    FStop := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
  if FThread <> nil then
  begin
    FThread.WaitFor;
    FThread.Free;
    FThread := nil;
  end;
  FDetails.Free;
  FWake.Free;
  FLock.Free;
  inherited;
end;

procedure TProcessCollector.FillDetails(var AEntries: TArray<TProcessTopEntry>;
  ATitles: TDictionary<Cardinal, string>);
var
  i: Integer;
  Key, Title: string;
  Pid: Cardinal;
  D: TProcessDetail;
begin
  for i := 0 to High(AEntries) do
  begin
    { Window titles change, so they are looked up fresh every sample. }
    for Pid in AEntries[i].Pids do
      if ATitles.TryGetValue(Pid, Title) and (Title <> '') then
      begin
        AEntries[i].WindowTitle := Title;
        Break;
      end;

    Key := LowerCase(AEntries[i].Name);
    if not FDetails.TryGetValue(Key, D) then
    begin
      D := Default(TProcessDetail);
      if not ReadProcessInfo(AEntries[i].Pid, D) then
        Continue;
      ReadVersionStrings(D.Path, D);
      if FDetails.Count >= CMaxDetailCache then
        FDetails.Clear;
      FDetails.Add(Key, D);
    end;
    AEntries[i].HasDetail := True;
    AEntries[i].Detail := D;
  end;
end;

procedure TProcessCollector.SetActive(AActive: Boolean);
begin
  FLock.Enter;
  try
    if FActive = AActive then
      Exit;
    FActive := AActive;
    if not AActive then
      FTop := Default(TProcessTop);
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TProcessCollector.SetInterval(ASec: Integer);
begin
  if ASec < 1 then
    ASec := 1;
  FLock.Enter;
  try
    if FIntervalMs = Cardinal(ASec) * 1000 then
      Exit;
    FIntervalMs := Cardinal(ASec) * 1000;
  finally
    FLock.Leave;
  end;
  { Wake the worker so the new period applies now: it samples once (averaged
    over the time since the last sample) and then waits the new period. }
  FWake.SetEvent;
end;

procedure TProcessCollector.SetPaused(APaused: Boolean);
begin
  FLock.Enter;
  try
    if FPaused = APaused then
      Exit;
    FPaused := APaused;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TProcessCollector.CopyTop(out ATop: TProcessTop);
begin
  { The worker replaces FTop wholesale and never edits its arrays in place, so
    sharing the (reference-counted) arrays with the UI thread is safe. }
  FLock.Enter;
  try
    ATop := FTop;
  finally
    FLock.Leave;
  end;
end;

function TProcessCollector.InitPdh: Boolean;
var
  C: TProcessCounter;
begin
  Result := False;
  ClosePdh;
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  for C := Low(TProcessCounter) to High(TProcessCounter) do
    if PdhAddEnglishCounterW(FQuery, PWideChar(CCounterPaths[C]), 0,
      FCounters[C]) <> 0 then
    begin
      ClosePdh;
      Exit;
    end;
  { Rate counters need two collects; this one primes them. }
  PdhCollectQueryData(FQuery);
  FFailCount := 0;
  Result := True;
end;

procedure TProcessCollector.ClosePdh;
var
  C: TProcessCounter;
begin
  if FQuery <> 0 then
  begin
    PdhCloseQuery(FQuery);
    FQuery := 0;
  end;
  for C := Low(TProcessCounter) to High(TProcessCounter) do
    FCounters[C] := 0;
end;

function TProcessCollector.SamplePdh(out ATop: TProcessTop): Boolean;
var
  Index: TDictionary<string, Integer>;
  Aggs: TArray<TProcessAgg>;
  AggCount: Integer;

  { Row for this instance's name, created on first sight. ACountIt adds the
    instance to the row's process count and PID list -- done for one counter
    only so each process is counted once. }
  function AggFor(AItem: PPdhFmtCounterValueItemW; ACountIt: Boolean): Integer;
  var
    Name, Key: string;
    Pid: Cardinal;
  begin
    Result := -1;
    if not SplitInstance(AItem.szName, Name, Pid) then
      Exit;
    Key := LowerCase(Name);
    if not Index.TryGetValue(Key, Result) then
    begin
      if AggCount = Length(Aggs) then
        SetLength(Aggs, AggCount * 2 + 64);
      Result := AggCount;
      Inc(AggCount);
      Aggs[Result] := Default(TProcessAgg);
      Aggs[Result].Name := Name;
      Aggs[Result].Pid := Pid;
      Index.Add(Key, Result);
    end;
    if ACountIt then
    begin
      Inc(Aggs[Result].Count);
      if Pid <> 0 then
        Aggs[Result].Pids := Aggs[Result].Pids + [Pid];
    end;
  end;

var
  Items: array[TProcessCounter] of PPdhFmtCounterValueItemW;
  Counts: array[TProcessCounter] of DWORD;
  Item: PPdhFmtCounterValueItemW;
  C: TProcessCounter;
  i, A: Integer;
  V: Double;
  Titles: TDictionary<Cardinal, string>;
begin
  Result := False;
  ATop := Default(TProcessTop);
  if FQuery = 0 then
    Exit;
  if PdhCollectQueryData(FQuery) <> 0 then
    Exit;
  for C := Low(TProcessCounter) to High(TProcessCounter) do
    if not FetchArray(FCounters[C], CCounterFormats[C], FBufs[C], Items[C],
      Counts[C]) then
      Exit;

  AggCount := 0;
  Index := TDictionary<string, Integer>.Create;
  try
    { Each counter is matched by instance name on its own, so the arrays need
      not list processes in the same order. The memory counter does the
      counting (pcMem is the first non-rate counter, valid from the first
      collect). }
    for C := Low(TProcessCounter) to High(TProcessCounter) do
      for i := 0 to Integer(Counts[C]) - 1 do
      begin
        Item := ItemAt(Items[C], i);
        if not ItemValid(Item) then
          Continue;
        A := AggFor(Item, C = pcMem);
        if A < 0 then
          Continue;
        if (CCounterFormats[C] and PDH_FMT_LARGE) <> 0 then
          V := Item.FmtValue.LargeValue
        else
          V := Item.FmtValue.DoubleValue;
        Aggs[A].Vals[C] := Aggs[A].Vals[C] + V;
      end;
  finally
    Index.Free;
  end;

  ATop.Items[prCpu] := TopBy(Aggs, AggCount, prCpu);
  ATop.Items[prMem] := TopBy(Aggs, AggCount, prMem);
  ATop.Items[prIo] := TopBy(Aggs, AggCount, prIo);
  Titles := BuildWindowTitles;
  try
    FillDetails(ATop.Items[prCpu], Titles);
    FillDetails(ATop.Items[prMem], Titles);
    FillDetails(ATop.Items[prIo], Titles);
  finally
    Titles.Free;
  end;
  ATop.Valid := True;
  Result := True;
end;

procedure TProcessCollector.WorkerExecute;
var
  Stop, Active: Boolean;
  Top: TProcessTop;
  Wait: Cardinal;
begin
  while True do
  begin
    FLock.Enter;
    try
      Stop := FStop;
      { A pause idles the worker like an inactive page, but FTop stays. }
      Active := FActive and not FPaused;
      Wait := FIntervalMs;
    finally
      FLock.Leave;
    end;
    if Stop then
      Break;

    if not Active then
    begin
      ClosePdh;
      FWake.WaitFor(INFINITE);
      Continue;
    end;

    try
      if FQuery = 0 then
      begin
        { A fresh init only primes the counters. Take the first sample after a
          short wait rather than a full (up to 10 s) period, so the page isn't
          blank for long; later samples follow the chosen period. A failed init
          waits for the retry interval. }
        if InitPdh then
          Wait := CFirstSampleMs
        else
          Wait := CRetryIntervalMs;
      end
      else if SamplePdh(Top) then
      begin
        FFailCount := 0;
        FLock.Enter;
        try
          { SetActive(False) may have landed during the sample; don't
            resurrect a result it just discarded. Nor change a list the user
            has just frozen. }
          if FActive and not FPaused then
            FTop := Top;
        finally
          FLock.Leave;
        end;
      end
      else
      begin
        Inc(FFailCount);
        if FFailCount >= CMaxFailsBeforeRetry then
          ClosePdh;
      end;
    except
      ClosePdh;
      Wait := CRetryIntervalMs;
    end;
    { SetActive and Destroy set the event, so neither waits out the interval. }
    FWake.WaitFor(Wait);
  end;
  ClosePdh;
end;

{ TProcessIconCache }

constructor TProcessIconCache.Create;
begin
  inherited Create;
  FIcons := TDictionary<string, THandle>.Create;
end;

destructor TProcessIconCache.Destroy;
var
  H: THandle;
begin
  if FIcons <> nil then
    for H in FIcons.Values do
      if H <> 0 then
        DestroyIcon(HICON(H));
  FIcons.Free;
  inherited;
end;

function TProcessIconCache.LoadSized(const AFile: string; AIndex,
  ASize: Integer): THandle;
var
  Icon: HICON;
begin
  Result := 0;
  Icon := 0;
  if (AFile <> '') and
    (SHDefExtractIconW_(PWideChar(AFile), AIndex, 0, @Icon, nil,
      UINT(ASize) and $FFFF) = S_OK) then
    Result := THandle(Icon);
end;

function TProcessIconCache.StockIcon(ASize: Integer): THandle;
var
  Info: TStockIconInfo;
begin
  { SHGSI_ICONLOCATION gives the stock icon's file and index, so it can be
    extracted at the exact size like any other. }
  Result := 0;
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  if SHGetStockIconInfo_(SIID_APPLICATION_, SHGSI_ICONLOCATION_, Info) = S_OK then
    Result := LoadSized(Info.szPath, Info.iIcon, ASize);
end;

function TProcessIconCache.IconFor(const APath: string; ASize: Integer): THandle;
var
  Key: string;
  H: THandle;
begin
  if ASize < 16 then
    ASize := 16;
  Key := LowerCase(APath) + '|' + IntToStr(ASize);
  if not FIcons.TryGetValue(Key, H) then
  begin
    if APath = '' then
      H := StockIcon(ASize)
    else
      H := LoadSized(APath, 0, ASize);
    { Cached even when 0, so an executable without an icon resource is not
      re-extracted on every repaint. }
    FIcons.Add(Key, H);
  end;
  { No path (process couldn't be opened) or no icon in the file: share the
    one stock icon per size, owned under the '' key. }
  if (H = 0) and (APath <> '') then
    H := IconFor('', ASize);
  Result := H;
end;

end.
