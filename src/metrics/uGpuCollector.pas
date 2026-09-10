unit uGpuCollector;

{ GPU utilization via PDH "\GPU Engine(*)\Utilization Percentage".

  The GPU Engine counter has dynamic wildcard instances -- one per
  (process, adapter, physical engine, engine type) -- that come and go as
  processes open and close GPU contexts. A single wildcard counter plus
  PdhGetFormattedCounterArray tracks that churn without re-adding counters.

  Aggregation matches the headline "Utilization" each GPU card shows in Task
  Manager's Performance tab: sum the per-process values within one
  (adapter, engine-type) group, then take the max over engine types, then the
  max over adapters. That last two maxes collapse to a single "max over all
  (adapter, engine-type) groups".

  Sample returns 0..100, or 0 when the counter set is absent (older Windows,
  an RDP session, a machine with no GPU performance counters) -- the dashboard
  treats that the same as an idle GPU. }

interface

type
  TGpuCollector = class
  private
    FQuery: THandle;
    FCounter: THandle;
    FUsePdh: Boolean;
    FPrimed: Boolean;
    FBuf: array of Byte;
    FLast: Double;
    function InitPdh: Boolean;
    procedure ClosePdh;
    function SamplePdh(out AValue: Double): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Sample: Double;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
  Winapi.Windows;

const
  PDH_FMT_DOUBLE = $00000200;
  PDH_MORE_DATA = $800007D2;
  PDH_CSTATUS_VALID_DATA = $00000000;
  PDH_CSTATUS_NEW_DATA = $00000001;
  CGpuWildcardPath = '\GPU Engine(*)\Utilization Percentage';

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

{ Instance names look like
    pid_29612_luid_0x00000000_0x0000C4C1_phys_0_eng_0_engtype_3D
  luid identifies the adapter, engtype the engine class (3D / Copy / VideoDecode
  / ...). Lower-cased first so grouping keys are stable regardless of how PDH
  cases the instance string. }
function ParseLuidEngType(const AName: string; out ALuid, AEngType: string): Boolean;
var
  N: string;
  P, Q: Integer;
begin
  Result := False;
  ALuid := '';
  AEngType := '';
  N := LowerCase(AName);
  P := Pos('_luid_', N);
  if P = 0 then
    Exit;
  Q := Pos('_phys_', N);
  if Q <= P + 6 then
    Exit;
  ALuid := Copy(N, P + 6, Q - (P + 6));
  P := Pos('_engtype_', N);
  if P = 0 then
    Exit;
  AEngType := Copy(N, P + 9, MaxInt);
  Result := (ALuid <> '') and (AEngType <> '');
end;

constructor TGpuCollector.Create;
begin
  inherited Create;
  FLast := 0;
  FUsePdh := InitPdh;
end;

destructor TGpuCollector.Destroy;
begin
  ClosePdh;
  inherited;
end;

function TGpuCollector.InitPdh: Boolean;
begin
  Result := False;
  FQuery := 0;
  FCounter := 0;
  FPrimed := False;
  if PdhOpenQueryW(nil, 0, FQuery) <> 0 then
  begin
    FQuery := 0;
    Exit;
  end;
  if PdhAddEnglishCounterW(FQuery, CGpuWildcardPath, 0, FCounter) <> 0 then
  begin
    ClosePdh;
    Exit;
  end;
  { First collect primes the counter; formatted values are valid from the
    second collect on. }
  PdhCollectQueryData(FQuery);
  Result := True;
end;

procedure TGpuCollector.ClosePdh;
begin
  if FQuery <> 0 then
  begin
    PdhCloseQuery(FQuery);
    FQuery := 0;
  end;
  FCounter := 0;
end;

function TGpuCollector.SamplePdh(out AValue: Double): Boolean;
var
  BufSize, ItemCount: DWORD;
  i: Integer;
  St: LongInt;
  Items, Item: PPdhFmtCounterValueItemW;
  Luid, EngType, Key: string;
  Groups: TDictionary<string, Double>;
  Cur, MaxUtil: Double;
begin
  Result := False;
  AValue := FLast;
  if (FQuery = 0) or (FCounter = 0) then
    Exit;
  if PdhCollectQueryData(FQuery) <> 0 then
    Exit;
  if not FPrimed then
  begin
    FPrimed := True;
    FLast := 0;
    AValue := 0;
    Exit(True);
  end;

  BufSize := DWORD(Length(FBuf));
  ItemCount := 0;
  if Length(FBuf) > 0 then
    Items := PPdhFmtCounterValueItemW(@FBuf[0])
  else
    Items := nil;
  St := PdhGetFormattedCounterArrayW(FCounter, PDH_FMT_DOUBLE, BufSize, ItemCount, Items);
  if DWORD(St) = PDH_MORE_DATA then
  begin
    SetLength(FBuf, Integer(BufSize));
    Items := PPdhFmtCounterValueItemW(@FBuf[0]);
    St := PdhGetFormattedCounterArrayW(FCounter, PDH_FMT_DOUBLE, BufSize, ItemCount, Items);
  end;
  if (St <> 0) or (Items = nil) then
  begin
    { No live instances (every GPU context closed) or a transient PDH error:
      report idle rather than holding a stale reading. }
    FLast := 0;
    AValue := 0;
    Exit(True);
  end;

  MaxUtil := 0;
  Groups := TDictionary<string, Double>.Create;
  try
    for i := 0 to Integer(ItemCount) - 1 do
    begin
      Item := PPdhFmtCounterValueItemW(PByte(Items) + i * SizeOf(TPdhFmtCounterValueItemW));
      if (Item.FmtValue.CStatus <> PDH_CSTATUS_VALID_DATA) and
        (Item.FmtValue.CStatus <> PDH_CSTATUS_NEW_DATA) then
        Continue;
      if Item.szName = nil then
        Continue;
      if not ParseLuidEngType(Item.szName, Luid, EngType) then
        Continue;
      Key := Luid + '|' + EngType;
      if Groups.TryGetValue(Key, Cur) then
        Groups[Key] := Cur + Item.FmtValue.DoubleValue
      else
        Groups.Add(Key, Item.FmtValue.DoubleValue);
    end;
    for Cur in Groups.Values do
      if Cur > MaxUtil then
        MaxUtil := Cur;
  finally
    Groups.Free;
  end;

  if MaxUtil < 0 then
    MaxUtil := 0
  else if MaxUtil > 100 then
    MaxUtil := 100;
  FLast := MaxUtil;
  AValue := MaxUtil;
  Result := True;
end;

function TGpuCollector.Sample: Double;
var
  V: Double;
begin
  if not FUsePdh then
    Exit(0);
  Result := FLast;
  try
    if SamplePdh(V) then
      Result := V;
  except
    FUsePdh := False;
    ClosePdh;
    FLast := 0;
    Result := 0;
  end;
end;

end.
