unit uNetCollector;

{ Real-NIC In/Out Byte/s via IP Helper GetIfTable. Excludes loopback / tunnel /
  common virtual adapters. Exposes max link speed (Byte/s) for RangeEngine. }

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
    FPrev: TNetIfPrevArray;
    FPrevTick: Cardinal;
    FHasPrev: Boolean;
    FLastInBps: Double;
    FLastOutBps: Double;
    FLastLinkSpeedBps: Double;
    function IsExcludedAdapter(AType: Cardinal; const ADescr: string): Boolean;
    function FindPrev(AIndex: Cardinal): Integer;
  public
    procedure Sample(out AInBps, AOutBps, ALinkSpeedBps: Double);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
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

function TNetCollector.FindPrev(AIndex: Cardinal): Integer;
var
  i: Integer;
begin
  for i := 0 to High(FPrev) do
    if FPrev[i].Used and (FPrev[i].Index = AIndex) then
      Exit(i);
  Result := -1;
end;

procedure TNetCollector.Sample(out AInBps, AOutBps, ALinkSpeedBps: Double);
var
  Size: DWORD;
  Status: DWORD;
  Buf: Pointer;
  Table: PMIBIfTable;
  i, PrevIdx, NewCount: Integer;
  Descr: string;
  Tick: Cardinal;
  ElapsedSec: Double;
  Row: PMIBIfRow;
  DeltaIn, DeltaOut: UInt64;
  TotalInBps, TotalOutBps: Double;
  MaxSpeedBits: DWORD;
  NextPrev: TNetIfPrevArray;
begin
  AInBps := FLastInBps;
  AOutBps := FLastOutBps;
  ALinkSpeedBps := FLastLinkSpeedBps;

  Size := 0;
  Status := GetIfTable(nil, Size, False);
  if (Status <> ERROR_INSUFFICIENT_BUFFER) and (Status <> ERROR_SUCCESS) then
    Exit;
  if Size = 0 then
    Exit;

  GetMem(Buf, Size);
  try
    Status := GetIfTable(Buf, Size, False);
    if Status <> ERROR_SUCCESS then
      Exit;

    Table := PMIBIfTable(Buf);
    Tick := GetTickCount;
    TotalInBps := 0;
    TotalOutBps := 0;
    MaxSpeedBits := 0;
    NewCount := 0;
    SetLength(NextPrev, Integer(Table.dwNumEntries));

    if FHasPrev then
      ElapsedSec := (Tick - FPrevTick) / 1000.0
    else
      ElapsedSec := 0;

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

      NextPrev[NewCount].Index := Row.dwIndex;
      NextPrev[NewCount].InOctets := Row.dwInOctets;
      NextPrev[NewCount].OutOctets := Row.dwOutOctets;
      NextPrev[NewCount].Used := True;

      if FHasPrev and (ElapsedSec > 0) then
      begin
        PrevIdx := FindPrev(Row.dwIndex);
        if PrevIdx >= 0 then
        begin
          DeltaIn := DWORD(Row.dwInOctets - FPrev[PrevIdx].InOctets);
          DeltaOut := DWORD(Row.dwOutOctets - FPrev[PrevIdx].OutOctets);
          TotalInBps := TotalInBps + DeltaIn / ElapsedSec;
          TotalOutBps := TotalOutBps + DeltaOut / ElapsedSec;
        end;
      end;

      Inc(NewCount);
    end;

    SetLength(NextPrev, NewCount);
    FPrev := NextPrev;
    FPrevTick := Tick;
    FHasPrev := True;

    if MaxSpeedBits > 0 then
    begin
      FLastLinkSpeedBps := MaxSpeedBits / 8.0;
      ALinkSpeedBps := FLastLinkSpeedBps;
    end;

    if ElapsedSec > 0 then
    begin
      FLastInBps := TotalInBps;
      FLastOutBps := TotalOutBps;
      AInBps := FLastInBps;
      AOutBps := FLastOutBps;
    end;
  finally
    FreeMem(Buf);
  end;
end;

end.
