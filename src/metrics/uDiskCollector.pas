unit uDiskCollector;

{ Physical disk Read/Write Byte/s. Prefers PDH PhysicalDisk(_Total); falls back
  to IOCTL_DISK_PERFORMANCE cumulative deltas when PDH is unavailable. }

interface

type
  TDiskCollector = class
  private
    FUsePdh: Boolean;
    FQuery: THandle;
    FReadCounter: THandle;
    FWriteCounter: THandle;
    FPdhReady: Boolean;
    FPrevReadBytes: UInt64;
    FPrevWriteBytes: UInt64;
    FPrevTick: Cardinal;
    FHasPrevIo: Boolean;
    FLastReadBps: Double;
    FLastWriteBps: Double;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SamplePdh(out AReadBps, AWriteBps: Double): Boolean;
    function SampleIoCtl(out AReadBps, AWriteBps: Double): Boolean;
    function SumDiskPerformance(out AReadBytes, AWriteBytes: UInt64): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Sample(out AReadBps, AWriteBps: Double);
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
  FPdhReady := False;
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
  FPdhReady := False;
end;

function TDiskCollector.SamplePdh(out AReadBps, AWriteBps: Double): Boolean;
var
  ReadVal, WriteVal: TPdhFmtCounterValue;
begin
  Result := False;
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
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
  Result := True;
end;

function TDiskCollector.SumDiskPerformance(out AReadBytes, AWriteBytes: UInt64): Boolean;
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
        Result := True;
      end;
    finally
      CloseHandle(H);
    end;
  end;
end;

function TDiskCollector.SampleIoCtl(out AReadBps, AWriteBps: Double): Boolean;
var
  ReadBytes, WriteBytes: UInt64;
  Tick: Cardinal;
  ElapsedSec: Double;
begin
  Result := False;
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
  if not SumDiskPerformance(ReadBytes, WriteBytes) then
    Exit;

  Tick := GetTickCount;
  if FHasPrevIo then
  begin
    ElapsedSec := (Tick - FPrevTick) / 1000.0;
    if ElapsedSec > 0 then
    begin
      AReadBps := (ReadBytes - FPrevReadBytes) / ElapsedSec;
      AWriteBps := (WriteBytes - FPrevWriteBytes) / ElapsedSec;
      FLastReadBps := AReadBps;
      FLastWriteBps := AWriteBps;
      Result := True;
    end;
  end
  else
    Result := True;

  FPrevReadBytes := ReadBytes;
  FPrevWriteBytes := WriteBytes;
  FPrevTick := Tick;
  FHasPrevIo := True;
end;

procedure TDiskCollector.Sample(out AReadBps, AWriteBps: Double);
begin
  AReadBps := FLastReadBps;
  AWriteBps := FLastWriteBps;
  if FUsePdh then
  begin
    if SamplePdh(AReadBps, AWriteBps) then
      Exit;
    { PDH broke at runtime — fall back for subsequent samples. }
    FUsePdh := False;
    ClosePdh;
  end;
  SampleIoCtl(AReadBps, AWriteBps);
end;

end.
