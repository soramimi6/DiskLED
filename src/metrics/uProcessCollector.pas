unit uProcessCollector;

{ Per-resource TOP5 processes for the dashboard's process page, via PDH
  "\Process V2(*)\...". Process V2 covers every process without elevation (the
  OpenProcess route reaches only about half of them); its instance names are
  "name:pid", unique per process.

  Same-named processes (chrome, svchost, ...) are summed into one row and ranked
  by that sum. Sampling runs on a worker thread at about 1 Hz -- one cycle over
  ~500 instances costs ~15 ms of PDH work -- and only while the process page is
  shown (SetActive). While inactive the PDH query is closed and the thread
  sleeps on its event, so the overview page costs nothing. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

const
  CProcessTopCount = 5;

type
  TProcessResource = (prCpu, prMem, prIo);

  TProcessTopEntry = record
    Name: string;
    { Instances summed into this row. }
    Count: Integer;
    { One PID of this name, for the icon. 0 when unknown. }
    Pid: Cardinal;
    { % Processor Time: one fully busy core = 100, so it can exceed 100. }
    CpuPct: Double;
    { Working Set - Private, matching Task Manager's memory column. }
    MemBytes: UInt64;
    { All I/O (file, network, device), not disk only. }
    IoReadBps: Double;
    IoWriteBps: Double;
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
    FTop: TProcessTop;
    { Worker-thread only. }
    FQuery: THandle;
    FCpuCounter: THandle;
    FMemCounter: THandle;
    FIoReadCounter: THandle;
    FIoWriteCounter: THandle;
    FCpuBuf: TBytes;
    FMemBuf: TBytes;
    FIoReadBuf: TBytes;
    FIoWriteBuf: TBytes;
    FFailCount: Integer;
    procedure WorkerExecute;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SamplePdh(out ATop: TProcessTop): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { True while the process page is shown. False also discards the last
      result, so the next activation starts from "no data" rather than
      showing a stale list. }
    procedure SetActive(AActive: Boolean);
    procedure CopyTop(out ATop: TProcessTop);
  end;

implementation

uses
  System.Generics.Collections,
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
  CCpuPath = '\Process V2(*)\% Processor Time';
  CMemPath = '\Process V2(*)\Working Set - Private';
  CIoReadPath = '\Process V2(*)\IO Read Bytes/sec';
  CIoWritePath = '\Process V2(*)\IO Write Bytes/sec';
  CSampleIntervalMs = 1000;
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
    Cpu: Double;
    Mem: Double;
    IoRead: Double;
    IoWrite: Double;
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

{ Highest CProcessTopCount rows of AAggs[0..ACount-1] by one resource. Rows
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
      prCpu: Rank[i].Key := AAggs[i].Cpu;
      prMem: Rank[i].Key := AAggs[i].Mem;
    else
      Rank[i].Key := AAggs[i].IoRead + AAggs[i].IoWrite;
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
  SetLength(Result, CProcessTopCount);
  N := 0;
  for i := 0 to ACount - 1 do
  begin
    if (N >= CProcessTopCount) or (Rank[i].Key <= 0) then
      Break;
    Src := AAggs[Rank[i].Idx];
    Result[N].Name := Src.Name;
    Result[N].Count := Src.Count;
    Result[N].Pid := Src.Pid;
    Result[N].CpuPct := Src.Cpu;
    Result[N].MemBytes := UInt64(Round(Src.Mem));
    Result[N].IoReadBps := Src.IoRead;
    Result[N].IoWriteBps := Src.IoWrite;
    Inc(N);
  end;
  SetLength(Result, N);
end;

constructor TProcessCollector.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
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
  FWake.Free;
  FLock.Free;
  inherited;
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
begin
  Result := False;
  ClosePdh;
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  if (PdhAddEnglishCounterW(FQuery, CCpuPath, 0, FCpuCounter) <> 0) or
    (PdhAddEnglishCounterW(FQuery, CMemPath, 0, FMemCounter) <> 0) or
    (PdhAddEnglishCounterW(FQuery, CIoReadPath, 0, FIoReadCounter) <> 0) or
    (PdhAddEnglishCounterW(FQuery, CIoWritePath, 0, FIoWriteCounter) <> 0) then
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
begin
  if FQuery <> 0 then
  begin
    PdhCloseQuery(FQuery);
    FQuery := 0;
  end;
  FCpuCounter := 0;
  FMemCounter := 0;
  FIoReadCounter := 0;
  FIoWriteCounter := 0;
end;

function TProcessCollector.SamplePdh(out ATop: TProcessTop): Boolean;
var
  Index: TDictionary<string, Integer>;
  Aggs: TArray<TProcessAgg>;
  AggCount: Integer;

  { Row for this instance's name, created on first sight. ACountIt adds the
    instance to the row's process count -- done for one counter only so each
    process is counted once. }
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
      Inc(Aggs[Result].Count);
  end;

var
  CpuItems, MemItems, ReadItems, WriteItems, Item: PPdhFmtCounterValueItemW;
  CpuN, MemN, ReadN, WriteN: DWORD;
  i, A: Integer;
begin
  Result := False;
  ATop := Default(TProcessTop);
  if FQuery = 0 then
    Exit;
  if PdhCollectQueryData(FQuery) <> 0 then
    Exit;
  if not FetchArray(FCpuCounter, PDH_FMT_DOUBLE or PDH_FMT_NOCAP100, FCpuBuf,
      CpuItems, CpuN) or
    not FetchArray(FMemCounter, PDH_FMT_LARGE, FMemBuf, MemItems, MemN) or
    not FetchArray(FIoReadCounter, PDH_FMT_DOUBLE, FIoReadBuf, ReadItems, ReadN) or
    not FetchArray(FIoWriteCounter, PDH_FMT_DOUBLE, FIoWriteBuf, WriteItems, WriteN) then
    Exit;

  AggCount := 0;
  Index := TDictionary<string, Integer>.Create;
  try
    { Each counter is matched by instance name on its own, so the four arrays
      need not list processes in the same order. }
    for i := 0 to Integer(MemN) - 1 do
    begin
      Item := ItemAt(MemItems, i);
      if not ItemValid(Item) then
        Continue;
      A := AggFor(Item, True);
      if A >= 0 then
        Aggs[A].Mem := Aggs[A].Mem + Item.FmtValue.LargeValue;
    end;
    for i := 0 to Integer(CpuN) - 1 do
    begin
      Item := ItemAt(CpuItems, i);
      if not ItemValid(Item) then
        Continue;
      A := AggFor(Item, False);
      if A >= 0 then
        Aggs[A].Cpu := Aggs[A].Cpu + Item.FmtValue.DoubleValue;
    end;
    for i := 0 to Integer(ReadN) - 1 do
    begin
      Item := ItemAt(ReadItems, i);
      if not ItemValid(Item) then
        Continue;
      A := AggFor(Item, False);
      if A >= 0 then
        Aggs[A].IoRead := Aggs[A].IoRead + Item.FmtValue.DoubleValue;
    end;
    for i := 0 to Integer(WriteN) - 1 do
    begin
      Item := ItemAt(WriteItems, i);
      if not ItemValid(Item) then
        Continue;
      A := AggFor(Item, False);
      if A >= 0 then
        Aggs[A].IoWrite := Aggs[A].IoWrite + Item.FmtValue.DoubleValue;
    end;
  finally
    Index.Free;
  end;

  ATop.Items[prCpu] := TopBy(Aggs, AggCount, prCpu);
  ATop.Items[prMem] := TopBy(Aggs, AggCount, prMem);
  ATop.Items[prIo] := TopBy(Aggs, AggCount, prIo);
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
      Active := FActive;
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

    Wait := CSampleIntervalMs;
    try
      if FQuery = 0 then
      begin
        { A fresh init only primes the counters; the first values come one
          interval later. A failed init waits for the retry interval. }
        if not InitPdh then
          Wait := CRetryIntervalMs;
      end
      else if SamplePdh(Top) then
      begin
        FFailCount := 0;
        FLock.Enter;
        try
          { SetActive(False) may have landed during the sample; don't
            resurrect a result it just discarded. }
          if FActive then
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

end.
