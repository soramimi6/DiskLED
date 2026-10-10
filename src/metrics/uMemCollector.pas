unit uMemCollector;

{ Physical memory, page file and commit charge.

  - SWAP is page file usage (in use / size of all page files), from PDH
    "\Paging File(_Total)\% Usage": its raw value carries both, in pages.
    GlobalMemoryStatusEx's "page file" fields are the commit charge and
    limit, not the page file, so they are not used for SWAP. Without the
    counter, SWAP stays 0 with a total of 0, which the UI shows as unknown.
  - Standby is the standby list, from PDH "\Memory\Standby Cache *" (Task
    Manager's "Cached" is this plus the small modified list).
    GetPerformanceInfo's SystemCache is the fallback: it counts the system
    working set instead, and runs well short of the standby list.

  Both move slowly and are shown at 1 Hz, so the PDH query is collected once a
  second; the physical-memory figures are read every call. }

interface

type
  TMemCollector = class
  private
    FQuery: THandle;
    FStandby: array[0..2] of THandle;
    FPageFile: THandle;
    FPdhTried: Boolean;
    FTick: Cardinal;
    FHasTick: Boolean;
    FHasStandby: Boolean;
    FStandbyBytes: UInt64;
    FHasPageFile: Boolean;
    FPageUsedPages: UInt64;
    FPageTotalPages: UInt64;
    function InitPdh: Boolean;
    procedure SamplePdh;
  public
    destructor Destroy; override;
    procedure Sample(out AMemUsage, ASwapUsage: Double;
      out AMemUsed, AMemTotal, AMemAvail, AMemCache,
      ASwapUsed, ASwapTotal, ACommit, ACommitLimit: UInt64);
  end;

implementation

uses
  Winapi.Windows;

const
  PDH_FMT_LARGE = $00000400;
  CStandbyPaths: array[0..2] of string = (
    '\Memory\Standby Cache Core Bytes',
    '\Memory\Standby Cache Normal Priority Bytes',
    '\Memory\Standby Cache Reserve Bytes');
  CPageFilePath = '\Paging File(_Total)\% Usage';
  CIntervalMs = 1000;

type
  TWinPerfInfo = record
    cb: DWORD;
    CommitTotal: NativeUInt;
    CommitLimit: NativeUInt;
    CommitPeak: NativeUInt;
    PhysicalTotal: NativeUInt;
    PhysicalAvailable: NativeUInt;
    SystemCache: NativeUInt;
    KernelTotal: NativeUInt;
    KernelPaged: NativeUInt;
    KernelNonpaged: NativeUInt;
    PageSize: NativeUInt;
    HandleCount: DWORD;
    ProcessCount: DWORD;
    ThreadCount: DWORD;
  end;

  TPdhFmtCounterValue = record
    CStatus: LongWord;
    case Integer of
      0: (LongValue: Int32);
      1: (DoubleValue: Double);
      2: (LargeValue: Int64);
      3: (WideStringValue: PWideChar);
  end;

  { PDH_RAW_COUNTER. For "% Usage" FirstValue is the pages in use and
    SecondValue the page file size in pages. }
  TPdhRawCounter = record
    CStatus: DWORD;
    TimeStamp: TFileTime;
    FirstValue: Int64;
    SecondValue: Int64;
    MultiCount: DWORD;
  end;

function GetWinPerfInfo(var PerfInfo: TWinPerfInfo; cb: DWORD): BOOL; stdcall;
  external 'psapi.dll' name 'GetPerformanceInfo';
function PdhOpenQueryW(szDataSource: PWideChar; dwUserData: NativeUInt;
  var phQuery: THandle): LongInt; stdcall; external 'pdh.dll' name 'PdhOpenQueryW';
function PdhCloseQuery(hQuery: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhCloseQuery';
function PdhAddEnglishCounterW(hQuery: THandle; szFullCounterPath: PWideChar;
  dwUserData: NativeUInt; var phCounter: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhAddEnglishCounterW';
function PdhCollectQueryData(hQuery: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhCollectQueryData';
function PdhGetFormattedCounterValue(hCounter: THandle; dwFormat: DWORD;
  lpdwType: PDWORD; var pValue: TPdhFmtCounterValue): LongInt; stdcall;
  external 'pdh.dll' name 'PdhGetFormattedCounterValue';
function PdhGetRawCounterValue(hCounter: THandle; lpdwType: PDWORD;
  var pValue: TPdhRawCounter): LongInt; stdcall;
  external 'pdh.dll' name 'PdhGetRawCounterValue';

destructor TMemCollector.Destroy;
begin
  if FQuery <> 0 then
    PdhCloseQuery(FQuery);
  inherited;
end;

function TMemCollector.InitPdh: Boolean;
var
  i: Integer;
begin
  Result := False;
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  for i := 0 to High(CStandbyPaths) do
    if PdhAddEnglishCounterW(FQuery, PWideChar(CStandbyPaths[i]), 0,
      FStandby[i]) <> 0 then
    begin
      FStandby[0] := 0;
      Break;
    end;
  { No page file at all still adds the counter (size 0). }
  if PdhAddEnglishCounterW(FQuery, CPageFilePath, 0, FPageFile) <> 0 then
    FPageFile := 0;
  Result := True;
end;

procedure TMemCollector.SamplePdh;
var
  NowTick: Cardinal;
  i: Integer;
  V: TPdhFmtCounterValue;
  Raw: TPdhRawCounter;
  Sum: UInt64;
  Ok: Boolean;
begin
  if not FPdhTried then
  begin
    FPdhTried := True;
    InitPdh;
  end;
  if FQuery = 0 then
    Exit;
  NowTick := GetTickCount;
  if FHasTick and (NowTick - FTick < CIntervalMs) then
    Exit;
  FTick := NowTick;
  FHasTick := True;
  if PdhCollectQueryData(FQuery) <> 0 then
    Exit;

  if FStandby[0] <> 0 then
  begin
    Sum := 0;
    Ok := True;
    for i := 0 to High(FStandby) do
    begin
      if PdhGetFormattedCounterValue(FStandby[i], PDH_FMT_LARGE, nil, V) <> 0 then
      begin
        Ok := False;
        Break;
      end;
      if V.LargeValue > 0 then
        Inc(Sum, UInt64(V.LargeValue));
    end;
    if Ok then
    begin
      FStandbyBytes := Sum;
      FHasStandby := True;
    end;
  end;

  { CStatus 0 / 1 = valid / new data; no page file leaves the instance invalid.
    An invalid read drops the last values, so SWAP shows "unknown" rather than
    a stale figure. }
  FHasPageFile := (FPageFile <> 0) and
    (PdhGetRawCounterValue(FPageFile, nil, Raw) = 0) and
    (Raw.CStatus <= 1) and (Raw.FirstValue >= 0) and (Raw.SecondValue >= 0);
  if FHasPageFile then
  begin
    FPageUsedPages := UInt64(Raw.FirstValue);
    FPageTotalPages := UInt64(Raw.SecondValue);
  end;
end;

procedure TMemCollector.Sample(out AMemUsage, ASwapUsage: Double;
  out AMemUsed, AMemTotal, AMemAvail, AMemCache,
  ASwapUsed, ASwapTotal, ACommit, ACommitLimit: UInt64);
var
  Status: TMemoryStatusEx;
  Perf: TWinPerfInfo;
  Page: UInt64;
begin
  AMemUsage := 0;
  ASwapUsage := 0;
  AMemUsed := 0;
  AMemTotal := 0;
  AMemAvail := 0;
  AMemCache := 0;
  ASwapUsed := 0;
  ASwapTotal := 0;
  ACommit := 0;
  ACommitLimit := 0;
  FillChar(Status, SizeOf(Status), 0);
  Status.dwLength := SizeOf(Status);
  if not GlobalMemoryStatusEx(Status) then
    Exit;

  AMemTotal := Status.ullTotalPhys;
  AMemAvail := Status.ullAvailPhys;
  if Status.ullTotalPhys > Status.ullAvailPhys then
    AMemUsed := Status.ullTotalPhys - Status.ullAvailPhys
  else
    AMemUsed := 0;
  if Status.ullTotalPhys > 0 then
    AMemUsage := AMemUsed / Status.ullTotalPhys * 100.0;

  SamplePdh;
  FillChar(Perf, SizeOf(Perf), 0);
  Perf.cb := SizeOf(Perf);
  if GetWinPerfInfo(Perf, SizeOf(Perf)) and (Perf.PageSize > 0) then
  begin
    Page := UInt64(Perf.PageSize);
    ACommit := UInt64(Perf.CommitTotal) * Page;
    ACommitLimit := UInt64(Perf.CommitLimit) * Page;
    if FHasStandby then
      AMemCache := FStandbyBytes
    else
      AMemCache := UInt64(Perf.SystemCache) * Page;
    if FHasPageFile then
    begin
      ASwapUsed := FPageUsedPages * Page;
      ASwapTotal := FPageTotalPages * Page;
      if ASwapTotal > 0 then
        ASwapUsage := ASwapUsed / ASwapTotal * 100.0;
    end;
  end;

  if AMemUsage < 0 then
    AMemUsage := 0;
  if AMemUsage > 100 then
    AMemUsage := 100;
  if ASwapUsage < 0 then
    ASwapUsage := 0;
  if ASwapUsage > 100 then
    ASwapUsage := 100;
end;

end.
