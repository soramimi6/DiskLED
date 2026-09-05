unit uDiskCollector;

{ Physical disk Read/Write Byte/s. Prefers PDH PhysicalDisk(_Total); falls back
  to IOCTL_DISK_PERFORMANCE cumulative deltas when PDH is unavailable.
  Set CDebugForceLatencyUnavailable to False after the "—" UI is verified. }

interface

const
  { True: Sample always reports DiskLatencyMs as -1 (unavailable), regardless
    of what PDH/IOCTL actually measured. For visually verifying the dashboard's
    unavailable-latency ("—") display without needing a real unsupported system. }
  CDebugForceLatencyUnavailable = False;

type
  TDiskCollector = class
  private
    FUsePdh: Boolean;
    FQuery: THandle;
    FReadCounter: THandle;
    FWriteCounter: THandle;
    FQueueCounter: THandle;
    FReadIopsCounter: THandle;
    FWriteIopsCounter: THandle;
    FIdleCounter: THandle;
    FLatencyCounter: THandle;
    FPdhReady: Boolean;
    FPdhQueueOk: Boolean;
    FPdhIdleOk: Boolean;
    FPdhLatencyOk: Boolean;
    FLastQueue: Double;
    FLastReadIops: Double;
    FLastWriteIops: Double;
    FLastActivePct: Double;
    FLastLatencyMs: Double;
    FPrevReadBytes: UInt64;
    FPrevWriteBytes: UInt64;
    FPrevReadCount: UInt64;
    FPrevWriteCount: UInt64;
    FPrevServiceTicks: UInt64;
    FPrevTick: Cardinal;
    FHasPrevIo: Boolean;
    FLastReadBps: Double;
    FLastWriteBps: Double;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SamplePdh(out AReadBps, AWriteBps, AQueue, AReadIops,
      AWriteIops, AActivePct, ALatencyMs: Double): Boolean;
    function SampleIoCtl(out AReadBps, AWriteBps, AQueue, AReadIops,
      AWriteIops, AActivePct, ALatencyMs: Double): Boolean;
    function SumDiskPerformance(out AReadBytes, AWriteBytes, AReadCount,
      AWriteCount: UInt64; out AQueue: Double; out AServiceTimeTicks: UInt64): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Sample(out AReadBps, AWriteBps, AQueue, AReadIops,
      AWriteIops, AActivePct, ALatencyMs: Double);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  PDH_FMT_DOUBLE = $00000200;
  IOCTL_DISK_PERFORMANCE = $00070020;

type
  TPdhFmtCounterValue = record
    CStatus: LongWord;
    case Integer of
      0: (LongValue: Int32);
      1: (DoubleValue: Double);
      2: (LargeValue: Int64);
      3: (AnsiStringValue: PAnsiChar);
      4: (WideStringValue: PWideChar);
  end;

  TDiskPerformance = record
    BytesRead: Int64;
    BytesWritten: Int64;
    ReadTime: Int64;
    WriteTime: Int64;
    IdleTime: Int64;
    ReadCount: DWORD;
    WriteCount: DWORD;
    QueueDepth: DWORD;
    SplitCount: DWORD;
    QueryTime: Int64;
    StorageDeviceNumber: DWORD;
    StorageManagerName: array[0..7] of WideChar;
  end;

function PdhOpenQueryW(szDataSource: PWideChar; dwUserData: NativeUInt;
  var phQuery: THandle): LongInt; stdcall; external 'pdh.dll' name 'PdhOpenQueryW';
function PdhCloseQuery(hQuery: THandle): LongInt; stdcall; external 'pdh.dll' name 'PdhCloseQuery';
function PdhAddEnglishCounterW(hQuery: THandle; szFullCounterPath: PWideChar;
  dwUserData: NativeUInt; var phCounter: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhAddEnglishCounterW';
function PdhCollectQueryData(hQuery: THandle): LongInt; stdcall;
  external 'pdh.dll' name 'PdhCollectQueryData';
function PdhGetFormattedCounterValue(hCounter: THandle; dwFormat: DWORD;
  lpdwType: PDWORD; var pValue: TPdhFmtCounterValue): LongInt; stdcall;
  external 'pdh.dll' name 'PdhGetFormattedCounterValue';

constructor TDiskCollector.Create;
begin
  inherited Create;
  FUsePdh := InitPdh;
end;

destructor TDiskCollector.Destroy;
begin
  ClosePdh;
  inherited;
end;

function TDiskCollector.InitPdh: Boolean;
begin
  Result := False;
  FQuery := 0;
  FReadCounter := 0;
  FWriteCounter := 0;
  FQueueCounter := 0;
  FReadIopsCounter := 0;
  FWriteIopsCounter := 0;
  FIdleCounter := 0;
  FLatencyCounter := 0;
  FPdhReady := False;
  FPdhQueueOk := False;
  FPdhIdleOk := False;
  FPdhLatencyOk := False;
  FLastActivePct := -1;
  FLastLatencyMs := -1; { -1: not yet measured / unavailable, matching FLastActivePct's convention }
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  if PdhAddEnglishCounterW(FQuery,
    '\PhysicalDisk(_Total)\Disk Read Bytes/sec', 0, FReadCounter) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  if PdhAddEnglishCounterW(FQuery,
    '\PhysicalDisk(_Total)\Disk Write Bytes/sec', 0, FWriteCounter) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  FPdhQueueOk :=
    (PdhAddEnglishCounterW(FQuery,
      '\PhysicalDisk(_Total)\Current Disk Queue Length', 0, FQueueCounter) = 0) and
    (PdhAddEnglishCounterW(FQuery,
      '\PhysicalDisk(_Total)\Disk Reads/sec', 0, FReadIopsCounter) = 0) and
    (PdhAddEnglishCounterW(FQuery,
      '\PhysicalDisk(_Total)\Disk Writes/sec', 0, FWriteIopsCounter) = 0);
  FPdhIdleOk := PdhAddEnglishCounterW(FQuery,
    '\PhysicalDisk(_Total)\% Idle Time', 0, FIdleCounter) = 0;
  FPdhLatencyOk := PdhAddEnglishCounterW(FQuery,
    '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer', 0, FLatencyCounter) = 0;
  { First collect establishes a baseline; values are valid from the second call. }
  PdhCollectQueryData(FQuery);
  FPdhReady := False;
  Result := True;
end;

procedure TDiskCollector.ClosePdh;
begin
  if FQuery <> 0 then
  begin
    PdhCloseQuery(FQuery);
    FQuery := 0;
  end;
  FReadCounter := 0;
  FWriteCounter := 0;
  FQueueCounter := 0;
  FReadIopsCounter := 0;
  FWriteIopsCounter := 0;
  FIdleCounter := 0;
  FLatencyCounter := 0;
  FPdhReady := False;
  FPdhQueueOk := False;
  FPdhIdleOk := False;
  FPdhLatencyOk := False;
end;

function TDiskCollector.SamplePdh(out AReadBps, AWriteBps, AQueue, AReadIops,
  AWriteIops, AActivePct, ALatencyMs: Double): Boolean;
var
  ReadVal, WriteVal, QueueVal, ReadIopsVal, WriteIopsVal, IdleVal,
    LatencyVal: TPdhFmtCounterValue;
begin
  Result := False;
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
  AQueue := FLastQueue;
  AReadIops := FLastReadIops;
  AWriteIops := FLastWriteIops;
  AActivePct := FLastActivePct;
  ALatencyMs := FLastLatencyMs;
  if FQuery = 0 then
    Exit;
  if PdhCollectQueryData(FQuery) <> 0 then
    Exit;
  if not FPdhReady then
  begin
    FPdhReady := True;
    Exit(True);
  end;
  if PdhGetFormattedCounterValue(FReadCounter, PDH_FMT_DOUBLE, nil, ReadVal) <> 0 then
    Exit;
  if PdhGetFormattedCounterValue(FWriteCounter, PDH_FMT_DOUBLE, nil, WriteVal) <> 0 then
    Exit;
  if ReadVal.DoubleValue < 0 then
    AReadBps := 0
  else
    AReadBps := ReadVal.DoubleValue;
  if WriteVal.DoubleValue < 0 then
    AWriteBps := 0
  else
    AWriteBps := WriteVal.DoubleValue;
  FLastReadBps := AReadBps;
  FLastWriteBps := AWriteBps;
  if FPdhQueueOk then
  begin
    if PdhGetFormattedCounterValue(FQueueCounter, PDH_FMT_DOUBLE, nil, QueueVal) = 0 then
    begin
      if QueueVal.DoubleValue < 0 then
        AQueue := 0
      else
        AQueue := QueueVal.DoubleValue;
      FLastQueue := AQueue;
    end;
    if PdhGetFormattedCounterValue(FReadIopsCounter, PDH_FMT_DOUBLE, nil, ReadIopsVal) = 0 then
    begin
      if ReadIopsVal.DoubleValue < 0 then
        AReadIops := 0
      else
        AReadIops := ReadIopsVal.DoubleValue;
      FLastReadIops := AReadIops;
    end;
    if PdhGetFormattedCounterValue(FWriteIopsCounter, PDH_FMT_DOUBLE, nil, WriteIopsVal) = 0 then
    begin
      if WriteIopsVal.DoubleValue < 0 then
        AWriteIops := 0
      else
        AWriteIops := WriteIopsVal.DoubleValue;
      FLastWriteIops := AWriteIops;
    end;
  end;
  if FPdhIdleOk then
  begin
    if PdhGetFormattedCounterValue(FIdleCounter, PDH_FMT_DOUBLE, nil, IdleVal) = 0 then
    begin
      if IdleVal.DoubleValue < 0 then
        AActivePct := 0
      else if IdleVal.DoubleValue > 100 then
        AActivePct := 0
      else
        AActivePct := 100.0 - IdleVal.DoubleValue;
      if AActivePct < 0 then
        AActivePct := 0;
      if AActivePct > 100 then
        AActivePct := 100;
      FLastActivePct := AActivePct;
    end;
  end;
  if FPdhLatencyOk then
  begin
    if PdhGetFormattedCounterValue(FLatencyCounter, PDH_FMT_DOUBLE, nil, LatencyVal) = 0 then
    begin
      if LatencyVal.DoubleValue < 0 then
        ALatencyMs := 0
      else
        ALatencyMs := LatencyVal.DoubleValue * 1000.0; { seconds -> ms }
      FLastLatencyMs := ALatencyMs;
    end;
  end;
  Result := True;
end;

function TDiskCollector.SumDiskPerformance(out AReadBytes, AWriteBytes, AReadCount,
  AWriteCount: UInt64; out AQueue: Double; out AServiceTimeTicks: UInt64): Boolean;
var
  i: Integer;
  Path: string;
  H: THandle;
  Perf: TDiskPerformance;
  BytesRet: DWORD;
begin
  Result := False;
  AReadBytes := 0;
  AWriteBytes := 0;
  AReadCount := 0;
  AWriteCount := 0;
  AQueue := 0;
  AServiceTimeTicks := 0;
  for i := 0 to 31 do
  begin
    Path := '\\.\PhysicalDrive' + IntToStr(i);
    H := CreateFile(PChar(Path), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
      OPEN_EXISTING, 0, 0);
    if H = INVALID_HANDLE_VALUE then
      Continue;
    try
      FillChar(Perf, SizeOf(Perf), 0);
      if DeviceIoControl(H, IOCTL_DISK_PERFORMANCE, nil, 0, @Perf, SizeOf(Perf),
        BytesRet, nil) then
      begin
        if Perf.BytesRead > 0 then
          Inc(AReadBytes, UInt64(Perf.BytesRead));
        if Perf.BytesWritten > 0 then
          Inc(AWriteBytes, UInt64(Perf.BytesWritten));
        Inc(AReadCount, Perf.ReadCount);
        Inc(AWriteCount, Perf.WriteCount);
        AQueue := AQueue + Perf.QueueDepth;
        if Perf.ReadTime > 0 then
          Inc(AServiceTimeTicks, UInt64(Perf.ReadTime));
        if Perf.WriteTime > 0 then
          Inc(AServiceTimeTicks, UInt64(Perf.WriteTime));
        Result := True;
      end;
    finally
      CloseHandle(H);
    end;
  end;
end;

function TDiskCollector.SampleIoCtl(out AReadBps, AWriteBps, AQueue, AReadIops,
  AWriteIops, AActivePct, ALatencyMs: Double): Boolean;
var
  ReadBytes, WriteBytes, ReadCount, WriteCount, ServiceTicks: UInt64;
  Tick: Cardinal;
  ElapsedSec: Double;
  DeltaCount, DeltaTicks: Int64;
begin
  Result := False;
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
  AQueue := FLastQueue;
  AReadIops := FLastReadIops;
  AWriteIops := FLastWriteIops;
  AActivePct := FLastActivePct;
  ALatencyMs := FLastLatencyMs;
  if not SumDiskPerformance(ReadBytes, WriteBytes, ReadCount, WriteCount, AQueue,
    ServiceTicks) then
    Exit;

  Tick := GetTickCount;
  if FHasPrevIo then
  begin
    ElapsedSec := (Tick - FPrevTick) / 1000.0;
    if ElapsedSec > 0 then
    begin
      AReadBps := (ReadBytes - FPrevReadBytes) / ElapsedSec;
      AWriteBps := (WriteBytes - FPrevWriteBytes) / ElapsedSec;
      AReadIops := (ReadCount - FPrevReadCount) / ElapsedSec;
      AWriteIops := (WriteCount - FPrevWriteCount) / ElapsedSec;
      DeltaCount := Int64(ReadCount - FPrevReadCount) + Int64(WriteCount - FPrevWriteCount);
      DeltaTicks := Int64(ServiceTicks - FPrevServiceTicks);
      if DeltaCount > 0 then
        ALatencyMs := (DeltaTicks * 0.0001) / DeltaCount { 100ns ticks -> ms }
      else
        ALatencyMs := 0;
      if ALatencyMs < 0 then
        ALatencyMs := 0;
      FLastReadBps := AReadBps;
      FLastWriteBps := AWriteBps;
      FLastQueue := AQueue;
      FLastReadIops := AReadIops;
      FLastWriteIops := AWriteIops;
      FLastLatencyMs := ALatencyMs;
      Result := True;
    end;
  end
  else
  begin
    { First sample: no prior tick to diff against, so latency stays at
      whatever FLastLatencyMs already is (-1 until a real reading lands). }
    FLastQueue := AQueue;
    Result := True;
  end;

  FPrevReadBytes := ReadBytes;
  FPrevWriteBytes := WriteBytes;
  FPrevReadCount := ReadCount;
  FPrevWriteCount := WriteCount;
  FPrevServiceTicks := ServiceTicks;
  FPrevTick := Tick;
  FHasPrevIo := True;
end;

procedure TDiskCollector.Sample(out AReadBps, AWriteBps, AQueue, AReadIops,
  AWriteIops, AActivePct, ALatencyMs: Double);
begin
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
  AQueue := FLastQueue;
  AReadIops := FLastReadIops;
  AWriteIops := FLastWriteIops;
  AActivePct := FLastActivePct;
  ALatencyMs := FLastLatencyMs;
  if FUsePdh then
  begin
    if SamplePdh(AReadBps, AWriteBps, AQueue, AReadIops, AWriteIops, AActivePct,
      ALatencyMs) then
    begin
      if CDebugForceLatencyUnavailable then
        ALatencyMs := -1;
      Exit;
    end;
    FUsePdh := False;
    ClosePdh;
  end;
  SampleIoCtl(AReadBps, AWriteBps, AQueue, AReadIops, AWriteIops, AActivePct,
    ALatencyMs);
  if CDebugForceLatencyUnavailable then
    ALatencyMs := -1;
end;

end.
