unit uDriveCollector;

{ Per-logical-drive disk read/write rates via PDH "\LogicalDisk(*)\...".

  Only instances named like "C:" are taken; "_Total" and "HarddiskVolumeN" are
  skipped. An instance whose data is not valid this sample (for example an
  empty optical drive) is reported as not present. }

interface

uses
  uMetricsTypes;

type
  TDriveCollector = class
  private
    FQuery: THandle;
    FReadCounter: THandle;
    FWriteCounter: THandle;
    FBuf: array of Byte;
    function InitPdh: Boolean;
    procedure ClosePdh;
    procedure ReadCounter(ACounter: THandle; var ARates: TDriveRates;
      var APresent: TDriveFlags);
  public
    destructor Destroy; override;
    procedure Sample(var ASnap: TMetricsSnapshot);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  PDH_FMT_DOUBLE = $00000200;
  PDH_MORE_DATA = $800007D2;
  PDH_CSTATUS_VALID_DATA = $00000000;
  PDH_CSTATUS_NEW_DATA = $00000001;
  CReadPath = '\LogicalDisk(*)\Disk Read Bytes/sec';
  CWritePath = '\LogicalDisk(*)\Disk Write Bytes/sec';
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

function DriveLetterOf(const AName: string; out ALetter: Char): Boolean;
begin
  Result := (Length(AName) = 2) and (AName[2] = ':') and
    CharInSet(UpCase(AName[1]), ['A'..'Z']);
  if Result then
    ALetter := UpCase(AName[1]);
end;

destructor TDriveCollector.Destroy;
begin
  ClosePdh;
  inherited;
end;

function TDriveCollector.InitPdh: Boolean;
begin
  Result := False;
  FQuery := 0;
  FReadCounter := 0;
  FWriteCounter := 0;
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  if (PdhAddEnglishCounterW(FQuery, CReadPath, 0, FReadCounter) <> 0) or
    (PdhAddEnglishCounterW(FQuery, CWritePath, 0, FWriteCounter) <> 0) then
  begin
    ClosePdh;
    Exit;
  end;
  PdhCollectQueryData(FQuery);
  Result := True;
end;

procedure TDriveCollector.ClosePdh;
begin
  if FQuery <> 0 then
    PdhCloseQuery(FQuery);
  FQuery := 0;
  FReadCounter := 0;
  FWriteCounter := 0;
end;

procedure TDriveCollector.ReadCounter(ACounter: THandle; var ARates: TDriveRates;
  var APresent: TDriveFlags);
var
  BufSize, ItemCount: DWORD;
  St: LongInt;
  Items, Item: PPdhFmtCounterValueItemW;
  Attempt, I: Integer;
  Letter: Char;
  Rate: Double;
begin
  BufSize := DWORD(Length(FBuf));
  ItemCount := 0;
  if Length(FBuf) > 0 then
    Items := PPdhFmtCounterValueItemW(@FBuf[0])
  else
    Items := nil;
  St := PdhGetFormattedCounterArrayW(ACounter, PDH_FMT_DOUBLE, BufSize, ItemCount, Items);
  Attempt := 0;
  while (DWORD(St) = PDH_MORE_DATA) and (Attempt < CMaxBufGrowAttempts) do
  begin
    Inc(Attempt);
    SetLength(FBuf, Integer(BufSize) + 64);
    BufSize := DWORD(Length(FBuf));
    Items := PPdhFmtCounterValueItemW(@FBuf[0]);
    St := PdhGetFormattedCounterArrayW(ACounter, PDH_FMT_DOUBLE, BufSize, ItemCount, Items);
  end;
  if (St <> 0) or (ItemCount = 0) or (Items = nil) then
    Exit;

  for I := 0 to Integer(ItemCount) - 1 do
  begin
    Item := PPdhFmtCounterValueItemW(PByte(Items) + I * SizeOf(TPdhFmtCounterValueItemW));
    if (Item.szName = nil) or (not DriveLetterOf(Item.szName, Letter)) then
      Continue;
    if (Item.FmtValue.CStatus <> PDH_CSTATUS_VALID_DATA) and
      (Item.FmtValue.CStatus <> PDH_CSTATUS_NEW_DATA) then
      Continue;
    Rate := Item.FmtValue.DoubleValue;
    if Rate < 0 then
      Rate := 0;
    ARates[Letter] := Rate;
    APresent[Letter] := True;
  end;
end;

procedure TDriveCollector.Sample(var ASnap: TMetricsSnapshot);
begin
  FillChar(ASnap.DrivePresent, SizeOf(ASnap.DrivePresent), 0);
  FillChar(ASnap.DriveReadBps, SizeOf(ASnap.DriveReadBps), 0);
  FillChar(ASnap.DriveWriteBps, SizeOf(ASnap.DriveWriteBps), 0);
  if (FQuery = 0) and (not InitPdh) then
    Exit;
  if PdhCollectQueryData(FQuery) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  ReadCounter(FReadCounter, ASnap.DriveReadBps, ASnap.DrivePresent);
  ReadCounter(FWriteCounter, ASnap.DriveWriteBps, ASnap.DrivePresent);
end;

end.
