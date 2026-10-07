unit uCpuCollector;

{ CPU usage as Task Manager shows it: PDH "\Processor Information(_Total)\
  % Processor Utility", which scales busy time by the clock (turbo raises it,
  throttling lowers it), capped at 100. Plain busy time (GetSystemTimes) reads
  noticeably lower than Task Manager on a turbo CPU, so it is only the
  fallback when the counter set is missing.

  Two windows:
  - every Sample (each frame) for the meter;
  - one second (Avg* / UserPct / KernelPct / CurrentMhz) for numbers, like
    Task Manager's 1 Hz refresh. A 60 ms frame of busy time is too coarse
    (scheduler tick 15.6 ms) to show as a number.

  CurrentMhz is "% Processor Performance" x "Processor Frequency" (base) --
  Task Manager's "Speed". CallNtPowerInformation's CurrentMhz is not used:
  on current Windows it reports each core's base clock, not the live one. }

interface

type
  TCpuCollector = class
  private
    FFrameQuery: THandle;
    FFrameUtil: THandle;
    FAvgQuery: THandle;
    FAvgUtil: THandle;
    FAvgPerf: THandle;
    FAvgFreq: THandle;
    FUsePdh: Boolean;
    FFailCount: Integer;
    FPrevIdle: UInt64;
    FPrevKernel: UInt64;
    FPrevUser: UInt64;
    FHasPrev: Boolean;
    FAvgPrevIdle: UInt64;
    FAvgPrevKernel: UInt64;
    FAvgPrevUser: UInt64;
    FAvgTick: Cardinal;
    FHasAvgTick: Boolean;
    FLast: Double;
    FAvgUsage: Double;
    FUserPct: Double;
    FKernelPct: Double;
    FName: string;
    FCores: Integer;
    FThreads: Integer;
    FMaxMhz: Integer;
    FCurrentMhz: Integer;
    procedure LoadStatic;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SampleFrame: Double;
    procedure SampleAverage;
  public
    constructor Create;
    destructor Destroy; override;
    { Usage over the time since the previous call (0..100), for the meter. }
    function Sample: Double;
    { Usage over the last one-second window (0..100); -1 until the first. }
    property AvgUsage: Double read FAvgUsage;
    property UserPct: Double read FUserPct;
    property KernelPct: Double read FKernelPct;
    property Name: string read FName;
    property Cores: Integer read FCores;
    property Threads: Integer read FThreads;
    property MaxMhz: Integer read FMaxMhz;
    { Live clock in MHz; 0 when unknown (the dashboard then shows MaxMhz). }
    property CurrentMhz: Integer read FCurrentMhz;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  RelProcessorCore = 0;
  PDH_FMT_DOUBLE = $00000200;
  { Utility and Performance exceed 100 on turbo; keep the raw value. }
  PDH_FMT_NOCAP100 = $00008000;
  CUtilPath = '\Processor Information(_Total)\% Processor Utility';
  CPerfPath = '\Processor Information(_Total)\% Processor Performance';
  CFreqPath = '\Processor Information(_Total)\Processor Frequency';
  CAvgWindowMs = 1000;
  CMaxFails = 10;

type
  TSysLogicalProcessorInformation = packed record
    ProcessorMask: ULONG_PTR;
    Relationship: DWORD;
    Pad: DWORD;
    Reserved: array[0..1] of UInt64;
  end;
  PSysLogicalProcessorInformation = ^TSysLogicalProcessorInformation;

  TPdhFmtCounterValue = record
    CStatus: LongWord;
    case Integer of
      0: (LongValue: Int32);
      1: (DoubleValue: Double);
      2: (LargeValue: Int64);
      3: (WideStringValue: PWideChar);
  end;

function GetLogicalProcessorInfo(Buffer: Pointer; var ReturnLength: DWORD): BOOL; stdcall;
  external 'kernel32.dll' name 'GetLogicalProcessorInformation';
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

function FileTimeToUInt64(const ATime: TFileTime): UInt64;
begin
  Result := (UInt64(ATime.dwHighDateTime) shl 32) or ATime.dwLowDateTime;
end;

function CollapseSpaces(const S: string): string;
var
  i: Integer;
begin
  Result := Trim(S);
  i := 1;
  while i < Length(Result) do
  begin
    if (Result[i] = ' ') and (Result[i + 1] = ' ') then
      Delete(Result, i + 1, 1)
    else
      Inc(i);
  end;
end;

function Clamp100(AValue: Double): Double;
begin
  if AValue < 0 then
    Result := 0
  else if AValue > 100 then
    Result := 100
  else
    Result := AValue;
end;

function ReadCounter(ACounter: THandle; out AValue: Double): Boolean;
var
  V: TPdhFmtCounterValue;
begin
  Result := (ACounter <> 0) and (PdhGetFormattedCounterValue(ACounter,
    PDH_FMT_DOUBLE or PDH_FMT_NOCAP100, nil, V) = 0);
  if Result then
    AValue := V.DoubleValue
  else
    AValue := 0;
end;

constructor TCpuCollector.Create;
begin
  inherited Create;
  FAvgUsage := -1;
  LoadStatic;
  FUsePdh := InitPdh;
end;

destructor TCpuCollector.Destroy;
begin
  ClosePdh;
  inherited;
end;

function TCpuCollector.InitPdh: Boolean;
begin
  Result := False;
  if PdhOpenQueryW(nil, 0, FFrameQuery) <> 0 then
  begin
    FFrameQuery := 0;
    Exit;
  end;
  if PdhAddEnglishCounterW(FFrameQuery, CUtilPath, 0, FFrameUtil) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  if PdhOpenQueryW(nil, 0, FAvgQuery) <> 0 then
  begin
    FAvgQuery := 0;
    ClosePdh;
    Exit;
  end;
  if PdhAddEnglishCounterW(FAvgQuery, CUtilPath, 0, FAvgUtil) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  { The clock is optional: without it the dashboard shows the base clock. }
  if (PdhAddEnglishCounterW(FAvgQuery, CPerfPath, 0, FAvgPerf) <> 0) or
    (PdhAddEnglishCounterW(FAvgQuery, CFreqPath, 0, FAvgFreq) <> 0) then
  begin
    FAvgPerf := 0;
    FAvgFreq := 0;
  end;
  { Rate counters need a first collect as the baseline. }
  PdhCollectQueryData(FFrameQuery);
  PdhCollectQueryData(FAvgQuery);
  Result := True;
end;

procedure TCpuCollector.ClosePdh;
begin
  if FFrameQuery <> 0 then
    PdhCloseQuery(FFrameQuery);
  if FAvgQuery <> 0 then
    PdhCloseQuery(FAvgQuery);
  FFrameQuery := 0;
  FFrameUtil := 0;
  FAvgQuery := 0;
  FAvgUtil := 0;
  FAvgPerf := 0;
  FAvgFreq := 0;
end;

procedure TCpuCollector.LoadStatic;
var
  Sys: TSystemInfo;
  K: HKEY;
  Buf: array[0..255] of Char;
  Sz, Typ, Mhz: DWORD;
  Need: DWORD;
  Raw: Pointer;
  Info: PSysLogicalProcessorInformation;
  Bytes, Step: Integer;
begin
  FName := '';
  FCores := 0;
  FThreads := 0;
  FMaxMhz := 0;
  GetSystemInfo(Sys);
  FThreads := Integer(Sys.dwNumberOfProcessors);
  if FThreads < 1 then
    FThreads := 1;

  Need := 0;
  GetLogicalProcessorInfo(nil, Need);
  if Need > 0 then
  begin
    GetMem(Raw, Need);
    try
      if GetLogicalProcessorInfo(Raw, Need) then
      begin
        Step := SizeOf(TSysLogicalProcessorInformation);
        if Step < 1 then
          Step := 1;
        Bytes := 0;
        while Bytes + Step <= Integer(Need) do
        begin
          Info := PSysLogicalProcessorInformation(NativeUInt(Raw) + NativeUInt(Bytes));
          if Info.Relationship = RelProcessorCore then
            Inc(FCores);
          Inc(Bytes, Step);
        end;
      end;
    finally
      FreeMem(Raw);
    end;
  end;
  if FCores < 1 then
    FCores := FThreads;

  if RegOpenKeyEx(HKEY_LOCAL_MACHINE,
    'HARDWARE\DESCRIPTION\System\CentralProcessor\0', 0, KEY_READ, K) = ERROR_SUCCESS then
  try
    Sz := SizeOf(Buf);
    FillChar(Buf, SizeOf(Buf), 0);
    if RegQueryValueEx(K, 'ProcessorNameString', nil, @Typ, @Buf[0], @Sz) = ERROR_SUCCESS then
      FName := CollapseSpaces(Buf);
    Sz := SizeOf(Mhz);
    if RegQueryValueEx(K, '~MHz', nil, @Typ, @Mhz, @Sz) = ERROR_SUCCESS then
      FMaxMhz := Integer(Mhz);
  finally
    RegCloseKey(K);
  end;
end;

{ Busy share of the time since the previous call, from GetSystemTimes. }
function BusyPct(AIdle, AKernel, AUser: UInt64; var APrevIdle, APrevKernel,
  APrevUser: UInt64; out AUserPct, AKernelPct: Double): Double;
var
  IdleDelta, KernelDelta, UserDelta, PrivDelta, TotalDelta: UInt64;
begin
  Result := -1;
  AUserPct := 0;
  AKernelPct := 0;
  IdleDelta := AIdle - APrevIdle;
  KernelDelta := AKernel - APrevKernel;
  UserDelta := AUser - APrevUser;
  TotalDelta := KernelDelta + UserDelta;
  APrevIdle := AIdle;
  APrevKernel := AKernel;
  APrevUser := AUser;
  if TotalDelta = 0 then
    Exit;
  if IdleDelta > TotalDelta then
    IdleDelta := TotalDelta;
  { Kernel time includes idle time. }
  if KernelDelta >= IdleDelta then
    PrivDelta := KernelDelta - IdleDelta
  else
    PrivDelta := 0;
  Result := Clamp100((1.0 - IdleDelta / TotalDelta) * 100.0);
  AUserPct := Clamp100(UserDelta / TotalDelta * 100.0);
  AKernelPct := Clamp100(PrivDelta / TotalDelta * 100.0);
end;

function TCpuCollector.SampleFrame: Double;
var
  IdleTime, KernelTime, UserTime: TFileTime;
  Busy, U, K, V: Double;
begin
  Result := FLast;
  if FUsePdh then
  begin
    if (PdhCollectQueryData(FFrameQuery) = 0) and ReadCounter(FFrameUtil, V) then
    begin
      FFailCount := 0;
      Exit(Clamp100(V));
    end;
    { A single miss (two collects too close together) keeps the last value;
      repeated misses mean the counter set went away: busy time from here on. }
    Inc(FFailCount);
    if FFailCount < CMaxFails then
      Exit;
    FUsePdh := False;
    ClosePdh;
  end;
  if not GetSystemTimes(IdleTime, KernelTime, UserTime) then
    Exit;
  if FHasPrev then
  begin
    Busy := BusyPct(FileTimeToUInt64(IdleTime), FileTimeToUInt64(KernelTime),
      FileTimeToUInt64(UserTime), FPrevIdle, FPrevKernel, FPrevUser, U, K);
    if Busy >= 0 then
      Result := Busy;
  end
  else
  begin
    FPrevIdle := FileTimeToUInt64(IdleTime);
    FPrevKernel := FileTimeToUInt64(KernelTime);
    FPrevUser := FileTimeToUInt64(UserTime);
    FHasPrev := True;
  end;
end;

procedure TCpuCollector.SampleAverage;
var
  IdleTime, KernelTime, UserTime: TFileTime;
  NowTick: Cardinal;
  Busy, U, K, Util, Perf, Freq, Scale: Double;
begin
  NowTick := GetTickCount;
  if FHasAvgTick and (NowTick - FAvgTick < CAvgWindowMs) then
    Exit;
  if not GetSystemTimes(IdleTime, KernelTime, UserTime) then
    Exit;
  if not FHasAvgTick then
  begin
    FAvgPrevIdle := FileTimeToUInt64(IdleTime);
    FAvgPrevKernel := FileTimeToUInt64(KernelTime);
    FAvgPrevUser := FileTimeToUInt64(UserTime);
    FAvgTick := NowTick;
    FHasAvgTick := True;
    Exit;
  end;
  FAvgTick := NowTick;
  Busy := BusyPct(FileTimeToUInt64(IdleTime), FileTimeToUInt64(KernelTime),
    FileTimeToUInt64(UserTime), FAvgPrevIdle, FAvgPrevKernel, FAvgPrevUser, U, K);
  if Busy < 0 then
    Exit;

  Util := Busy;
  if FUsePdh and (PdhCollectQueryData(FAvgQuery) = 0) then
  begin
    if ReadCounter(FAvgUtil, Util) then
      Util := Clamp100(Util)
    else
      Util := Busy;
    if ReadCounter(FAvgPerf, Perf) and ReadCounter(FAvgFreq, Freq) and
      (Perf > 0) and (Freq > 0) then
      FCurrentMhz := Round(Freq * Perf / 100.0)
    else
      FCurrentMhz := 0;
  end;
  FAvgUsage := Util;

  { The user / kernel split comes from busy time; scale it so the two parts
    add up to the utility figure shown next to them. }
  if Busy > 0 then
    Scale := Util / Busy
  else
    Scale := 0;
  FUserPct := Clamp100(U * Scale);
  FKernelPct := Clamp100(K * Scale);
  if FUserPct + FKernelPct > 100 then
    FKernelPct := 100 - FUserPct;
end;

function TCpuCollector.Sample: Double;
begin
  Result := SampleFrame;
  FLast := Result;
  SampleAverage;
end;

end.
