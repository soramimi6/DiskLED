unit uNetCollector;

{ Real-NIC In/Out Byte/s via IP Helper. Adapter list is refreshed every few
  seconds with GetIfTable; per-sample counters use GetIfEntry on cached
  indexes. Excludes loopback / tunnel / common virtual adapters. Exposes max
  link speed (Byte/s) for RangeEngine. }

interface

type
  TNetIfPrev = record
    Index: Cardinal;
    InOctets: Cardinal;
    OutOctets: Cardinal;
    Used: Boolean;
  end;
  TNetIfPrevArray = array of TNetIfPrev;

  TNetCollector = class
  private
    FIfs: TNetIfPrevArray;
    FPrevTick: Cardinal;
    FHasPrev: Boolean;
    FLastInBps: Double;
    FLastOutBps: Double;
    FLastLinkSpeedBps: Double;
    FTableSize: Cardinal;
    FLastRefreshTick: Cardinal;
    FHasList: Boolean;
    FForceRefresh: Boolean;
    function IsExcludedAdapter(AType: Cardinal; const ADescr: string): Boolean;
    function FindIf(AIndex: Cardinal): Integer;
    function RefreshAdapterList: Boolean;
    procedure SampleFromEntries(ATick: Cardinal);
  public
    procedure Sample(out AInBps, AOutBps, ALinkSpeedBps: Double);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  CAdapterRefreshMs = 3000;

  MAX_INTERFACE_NAME_LEN = 256;
  MAXLEN_IFDESCR = 256;
  MAXLEN_PHYSADDR = 8;

  IF_TYPE_SOFTWARE_LOOPBACK = 24;
  IF_TYPE_PPP = 23;
  IF_TYPE_SLIP = 28;
  IF_TYPE_TUNNEL = 131;
  IF_TYPE_PROP_VIRTUAL = 53;

type
  PMIBIfRow = ^TMIBIfRow;
  TMIBIfRow = record
    wszName: array[0..MAX_INTERFACE_NAME_LEN - 1] of WideChar;
    dwIndex: DWORD;
    dwType: DWORD;
    dwMtu: DWORD;
    dwSpeed: DWORD;
    dwPhysAddrLen: DWORD;
    bPhysAddr: array[0..MAXLEN_PHYSADDR - 1] of Byte;
    dwAdminStatus: DWORD;
    dwOperStatus: DWORD;
    dwLastChange: DWORD;
    dwInOctets: DWORD;
    dwInUcastPkts: DWORD;
    dwInNUcastPkts: DWORD;
    dwInDiscards: DWORD;
    dwInErrors: DWORD;
    dwInUnknownProtos: DWORD;
    dwOutOctets: DWORD;
    dwOutUcastPkts: DWORD;
    dwOutNUcastPkts: DWORD;
    dwOutDiscards: DWORD;
    dwOutErrors: DWORD;
    dwOutQLen: DWORD;
    dwDescrLen: DWORD;
    bDescr: array[0..MAXLEN_IFDESCR - 1] of AnsiChar;
  end;

  PMIBIfTable = ^TMIBIfTable;
  TMIBIfTable = record
    dwNumEntries: DWORD;
    Table: array[0..0] of TMIBIfRow;
  end;

function GetIfTable(pIfTable: Pointer; var pdwSize: DWORD; bOrder: BOOL): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetIfTable';
function GetIfEntry(pIfRow: Pointer): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetIfEntry';

function TNetCollector.IsExcludedAdapter(AType: Cardinal; const ADescr: string): Boolean;
var
  D: string;
begin
  case AType of
    IF_TYPE_SOFTWARE_LOOPBACK, IF_TYPE_PPP, IF_TYPE_SLIP, IF_TYPE_TUNNEL,
    IF_TYPE_PROP_VIRTUAL:
      Exit(True);
  end;

  D := LowerCase(ADescr);
  Result :=
    (Pos('loopback', D) > 0) or
    (Pos('virtual', D) > 0) or
    (Pos('hyper-v', D) > 0) or
    (Pos('vmware', D) > 0) or
    (Pos('virtualbox', D) > 0) or
    (Pos('vbox', D) > 0) or
    (Pos('tap-', D) > 0) or
    (Pos('tap adapter', D) > 0) or
    (Pos('wintun', D) > 0) or
    (Pos('wireguard', D) > 0) or
    (Pos('zerotier', D) > 0) or
    (Pos('nordlynx', D) > 0) or
    (Pos('isatap', D) > 0) or
    (Pos('teredo', D) > 0) or
    (Pos('microsoft wi-fi direct', D) > 0) or
    (Pos('bluetooth', D) > 0);
end;

function TNetCollector.FindIf(AIndex: Cardinal): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FIfs) do
    if FIfs[i].Used and (FIfs[i].Index = AIndex) then
      Exit(i);
  Result := -1;
end;

function TNetCollector.RefreshAdapterList: Boolean;
var
  Size: DWORD;
  Status: DWORD;
  Buf: Pointer;
  Table: PMIBIfTable;
  i, PrevIdx, NewCount: Integer;
  Descr: string;
  Row: PMIBIfRow;
  NextIfs: TNetIfPrevArray;
  MaxSpeedBits: DWORD;
begin
  Result := False;
  Size := FTableSize;
  if Size = 0 then
  begin
    Status := GetIfTable(nil, Size, False);
    if (Status <> ERROR_INSUFFICIENT_BUFFER) and (Status <> ERROR_SUCCESS) then
      Exit;
    if Size = 0 then
      Exit;
  end;

  GetMem(Buf, Size);
  try
    Status := GetIfTable(Buf, Size, False);
    if Status = ERROR_INSUFFICIENT_BUFFER then
    begin
      FreeMem(Buf);
      Buf := nil;
      GetMem(Buf, Size);
      Status := GetIfTable(Buf, Size, False);
    end;
    if Status <> ERROR_SUCCESS then
      Exit;

    FTableSize := Size;
    Table := PMIBIfTable(Buf);
    MaxSpeedBits := 0;
    NewCount := 0;
    SetLength(NextIfs, Integer(Table.dwNumEntries));

    for i := 0 to Integer(Table.dwNumEntries) - 1 do
    begin
      Row := PMIBIfRow(NativeUInt(@Table.Table[0]) + NativeUInt(i) * SizeOf(TMIBIfRow));
      SetString(Descr, PAnsiChar(@Row.bDescr[0]), Integer(Row.dwDescrLen));
      if (Length(Descr) > 0) and (Descr[Length(Descr)] = #0) then
        Delete(Descr, Length(Descr), 1);

      if IsExcludedAdapter(Row.dwType, Descr) then
        Continue;

      if Row.dwSpeed > MaxSpeedBits then
        MaxSpeedBits := Row.dwSpeed;

      NextIfs[NewCount].Index := Row.dwIndex;
      NextIfs[NewCount].Used := True;
      PrevIdx := FindIf(Row.dwIndex);
      if PrevIdx >= 0 then
      begin
        NextIfs[NewCount].InOctets := FIfs[PrevIdx].InOctets;
        NextIfs[NewCount].OutOctets := FIfs[PrevIdx].OutOctets;
      end
      else
      begin
        NextIfs[NewCount].InOctets := Row.dwInOctets;
        NextIfs[NewCount].OutOctets := Row.dwOutOctets;
      end;
      Inc(NewCount);
    end;

    SetLength(NextIfs, NewCount);
    FIfs := NextIfs;
    FHasList := True;
    FForceRefresh := False;
    FLastRefreshTick := GetTickCount;
    if MaxSpeedBits > 0 then
      FLastLinkSpeedBps := MaxSpeedBits / 8.0;
    Result := True;
  finally
    if Buf <> nil then
      FreeMem(Buf);
  end;
end;

procedure TNetCollector.SampleFromEntries(ATick: Cardinal);
var
  i: Integer;
  OkCount: Integer;
  Row: TMIBIfRow;
  ElapsedSec: Double;
  DeltaIn, DeltaOut: UInt64;
  TotalInBps, TotalOutBps: Double;
  MaxSpeedBits: DWORD;
begin
  if Length(FIfs) < 1 then
  begin
    FForceRefresh := True;
    Exit;
  end;

  if FHasPrev then
    ElapsedSec := (ATick - FPrevTick) / 1000.0
  else
    ElapsedSec := 0;

  OkCount := 0;
  TotalInBps := 0;
  TotalOutBps := 0;
  MaxSpeedBits := 0;

  for i := 0 to High(FIfs) do
  begin
    FillChar(Row, SizeOf(Row), 0);
    Row.dwIndex := FIfs[i].Index;
    if GetIfEntry(@Row) <> ERROR_SUCCESS then
      Continue;

    Inc(OkCount);
    if Row.dwSpeed > MaxSpeedBits then
      MaxSpeedBits := Row.dwSpeed;

    if FHasPrev and (ElapsedSec > 0) then
    begin
      DeltaIn := DWORD(Row.dwInOctets - FIfs[i].InOctets);
      DeltaOut := DWORD(Row.dwOutOctets - FIfs[i].OutOctets);
      TotalInBps := TotalInBps + DeltaIn / ElapsedSec;
      TotalOutBps := TotalOutBps + DeltaOut / ElapsedSec;
    end;

    FIfs[i].InOctets := Row.dwInOctets;
    FIfs[i].OutOctets := Row.dwOutOctets;
  end;

  if OkCount = 0 then
  begin
    FForceRefresh := True;
    Exit;
  end;

  if MaxSpeedBits > 0 then
    FLastLinkSpeedBps := MaxSpeedBits / 8.0;

  FPrevTick := ATick;
  FHasPrev := True;

  if ElapsedSec > 0 then
  begin
    FLastInBps := TotalInBps;
    FLastOutBps := TotalOutBps;
  end;
end;

procedure TNetCollector.Sample(out AInBps, AOutBps, ALinkSpeedBps: Double);
var
  Tick: Cardinal;
  NeedRefresh: Boolean;
begin
  AInBps := FLastInBps;
  AOutBps := FLastOutBps;
  ALinkSpeedBps := FLastLinkSpeedBps;

  Tick := GetTickCount;
  NeedRefresh := FForceRefresh or (not FHasList) or
    ((Tick - FLastRefreshTick) >= CAdapterRefreshMs);
  if NeedRefresh then
    RefreshAdapterList;

  if Length(FIfs) < 1 then
    Exit;

  SampleFromEntries(Tick);
  AInBps := FLastInBps;
  AOutBps := FLastOutBps;
  ALinkSpeedBps := FLastLinkSpeedBps;
end;

end.
