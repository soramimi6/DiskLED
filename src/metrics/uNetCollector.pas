unit uNetCollector;

{ Real-NIC In/Out Byte/s via IP Helper. Adapter list is refreshed every few
  seconds with GetIfTable; per-sample counters use GetIfEntry on cached
  indexes. Excludes loopback / tunnel / common virtual adapters from aggregate.
  Dashboard shows all non-loopback adapters with Included flag. }

interface

uses
  uMetricsTypes;

type
  TNetIfPrev = record
    Index: Cardinal;
    InOctets: Cardinal;
    OutOctets: Cardinal;
    Used: Boolean;
  end;
  TNetIfPrevArray = array of TNetIfPrev;

  TAdapterName = record
    Index: Cardinal;
    Name: string;
  end;

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
    FDisplayAdapters: TArray<TNetAdapterInfo>;
    FFriendlyNames: TArray<TAdapterName>;
    function IsExcludedAdapter(AType: Cardinal; const ADescr: string): Boolean;
    function IsLoopbackAdapter(AType: Cardinal): Boolean;
    function FindIf(AIndex: Cardinal): Integer;
    function FindFriendlyName(AIndex: Cardinal): string;
    procedure RefreshFriendlyNames;
    procedure ApplyAdapterConfig;
    function RefreshAdapterList: Boolean;
    procedure SampleFromEntries(ATick: Cardinal);
  public
    procedure Sample(out AInBps, AOutBps, ALinkSpeedBps: Double);
    procedure CopyDisplayAdapters(out AList: TArray<TNetAdapterInfo>);
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections,
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

  GAA_FLAG_INCLUDE_ALL_INTERFACES = $0100;
  AF_UNSPEC = 0;

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

  PIP_ADAPTER_ADDRESSES = ^IP_ADAPTER_ADDRESSES;
  IP_ADAPTER_ADDRESSES = record
    Length: ULONG;
    IfIndex: DWORD;
    Next: PIP_ADAPTER_ADDRESSES;
    AdapterName: PAnsiChar;
    FirstUnicastAddress: Pointer;
    FirstAnycastAddress: Pointer;
    FirstMulticastAddress: Pointer;
    FirstDnsServerAddress: Pointer;
    DnsSuffix: PWideChar;
    Description: PWideChar;
    FriendlyName: PWideChar;
    PhysicalAddress: array[0..7] of Byte;
    PhysicalAddressLength: ULONG;
    Flags: ULONG;
    Mtu: ULONG;
    IfType: ULONG;
    OperStatus: Integer;
    Ipv6IfIndex: DWORD;
    ZoneIndices: array[0..15] of DWORD;
    FirstPrefix: Pointer;
    TransmitLinkSpeed: UInt64;
    ReceiveLinkSpeed: UInt64;
    FirstWinsServerAddress: Pointer;
    FirstGatewayAddress: Pointer;
    Ipv4Metric: ULONG;
    Ipv6Metric: ULONG;
    Luid: UInt64;
    Dhcpv4Server: UInt64;
    CompartmentId: DWORD;
    NetworkGuid: TGUID;
    ConnectionType: DWORD;
    TunnelType: DWORD;
    AddressLength: Byte;
    Address: array[0..127] of Byte;
  end;

function GetIfTable(pIfTable: Pointer; var pdwSize: DWORD; bOrder: BOOL): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetIfTable';
function GetIfEntry(pIfRow: Pointer): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetIfEntry';
function GetAdaptersAddresses(Family: ULONG; Flags: ULONG; Reserved: Pointer;
  AdapterAddresses: PIP_ADAPTER_ADDRESSES; var SizePointer: ULONG): ULONG; stdcall;
  external 'iphlpapi.dll' name 'GetAdaptersAddresses';
function GetAdaptersInfo(AdapterInfo: Pointer; var SizePointer: ULONG): DWORD; stdcall;
  external 'iphlpapi.dll' name 'GetAdaptersInfo';

const
  MAX_ADAPTER_NAME_LENGTH = 256;
  MAX_ADAPTER_DESCRIPTION_LENGTH = 128;
  MAX_ADAPTER_ADDRESS_LENGTH = 8;

type
  PIP_ADDR_STRING = ^TIP_ADDR_STRING;
  TIP_ADDR_STRING = record
    Next: PIP_ADDR_STRING;
    IpAddress: array[0..15] of AnsiChar;
    IpMask: array[0..15] of AnsiChar;
    Context: DWORD;
  end;

  PIP_ADAPTER_INFO = ^TIP_ADAPTER_INFO;
  TIP_ADAPTER_INFO = record
    Next: PIP_ADAPTER_INFO;
    ComboIndex: DWORD;
    AdapterName: array[0..MAX_ADAPTER_NAME_LENGTH + 3] of AnsiChar;
    Description: array[0..MAX_ADAPTER_DESCRIPTION_LENGTH + 3] of AnsiChar;
    AddressLength: UINT;
    Address: array[0..MAX_ADAPTER_ADDRESS_LENGTH - 1] of Byte;
    Index: DWORD;
    AType: UINT;
    DhcpEnabled: UINT;
    CurrentIpAddress: PIP_ADDR_STRING;
    IpAddressList: TIP_ADDR_STRING;
    GatewayList: TIP_ADDR_STRING;
    DhcpServer: TIP_ADDR_STRING;
    HaveWins: BOOL;
    PrimaryWinsServer: TIP_ADDR_STRING;
    SecondaryWinsServer: TIP_ADDR_STRING;
    LeaseObtained: Int64;
    LeaseExpires: Int64;
  end;

function FirstIpText(const AList: TIP_ADDR_STRING): string;
begin
  Result := Trim(string(PAnsiChar(@AList.IpAddress[0])));
  if (Result = '') or (Result = '0.0.0.0') then
    Result := '';
end;

function TNetCollector.IsLoopbackAdapter(AType: Cardinal): Boolean;
begin
  Result := AType = IF_TYPE_SOFTWARE_LOOPBACK;
end;

function TNetCollector.IsExcludedAdapter(AType: Cardinal; const ADescr: string): Boolean;
var
  D: string;
begin
  if IsLoopbackAdapter(AType) then
    Exit(True);

  case AType of
    IF_TYPE_PPP, IF_TYPE_SLIP, IF_TYPE_TUNNEL, IF_TYPE_PROP_VIRTUAL:
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

function TNetCollector.FindFriendlyName(AIndex: Cardinal): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to High(FFriendlyNames) do
    if FFriendlyNames[i].Index = AIndex then
      Exit(FFriendlyNames[i].Name);
end;

procedure TNetCollector.RefreshFriendlyNames;
var
  Size: ULONG;
  Buf: Pointer;
  Status: ULONG;
  Cur: PIP_ADAPTER_ADDRESSES;
  Names: TList<TAdapterName>;
  Item: TAdapterName;
  Friendly: string;
begin
  Names := TList<TAdapterName>.Create;
  try
    Size := 0;
    Status := GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_ALL_INTERFACES,
      nil, nil, Size);
    if (Status <> ERROR_BUFFER_OVERFLOW) and (Status <> ERROR_SUCCESS) then
      Exit;
    GetMem(Buf, Size);
    try
      Status := GetAdaptersAddresses(AF_UNSPEC, GAA_FLAG_INCLUDE_ALL_INTERFACES,
        nil, PIP_ADAPTER_ADDRESSES(Buf), Size);
      if Status <> ERROR_SUCCESS then
        Exit;
      Cur := PIP_ADAPTER_ADDRESSES(Buf);
      while Cur <> nil do
      begin
        if (Cur^.FriendlyName <> nil) and (Cur^.FriendlyName^ <> #0) then
          Friendly := string(Cur^.FriendlyName)
        else if (Cur^.Description <> nil) and (Cur^.Description^ <> #0) then
          Friendly := string(Cur^.Description)
        else
          Friendly := '';
        if Friendly <> '' then
        begin
          Item.Index := Cur^.IfIndex;
          Item.Name := Friendly;
          Names.Add(Item);
        end;
        Cur := Cur^.Next;
      end;
    finally
      FreeMem(Buf);
    end;
    FFriendlyNames := Names.ToArray;
  finally
    Names.Free;
  end;
end;

procedure TNetCollector.ApplyAdapterConfig;
var
  Size, Status: ULONG;
  Buf: Pointer;
  Cur: PIP_ADAPTER_INFO;
  i: Integer;
  Ip, Gw: string;
begin
  Size := 0;
  Status := GetAdaptersInfo(nil, Size);
  if (Status <> ERROR_BUFFER_OVERFLOW) and (Status <> ERROR_SUCCESS) then
    Exit;
  if Size = 0 then
    Exit;
  GetMem(Buf, Size);
  try
    Status := GetAdaptersInfo(Buf, Size);
    if Status <> ERROR_SUCCESS then
      Exit;
    Cur := PIP_ADAPTER_INFO(Buf);
    while Cur <> nil do
    begin
      Ip := FirstIpText(Cur^.IpAddressList);
      Gw := FirstIpText(Cur^.GatewayList);
      for i := 0 to High(FDisplayAdapters) do
        if FDisplayAdapters[i].Index = Cur^.Index then
        begin
          FDisplayAdapters[i].Ipv4 := Ip;
          FDisplayAdapters[i].Gateway := Gw;
          FDisplayAdapters[i].DhcpEnabled := Cur^.DhcpEnabled <> 0;
          Break;
        end;
      Cur := Cur^.Next;
    end;
  finally
    FreeMem(Buf);
  end;
end;

function TNetCollector.RefreshAdapterList: Boolean;
var
  Size: DWORD;
  Status: DWORD;
  Buf: Pointer;
  Table: PMIBIfTable;
  i, PrevIdx, NewCount: Integer;
  Descr, Friendly: string;
  Row: PMIBIfRow;
  NextIfs: TNetIfPrevArray;
  MaxSpeedBits: DWORD;
  Included: Boolean;
  Info: TNetAdapterInfo;
  DisplayList: TList<TNetAdapterInfo>;
begin
  Result := False;
  RefreshFriendlyNames;

    Size := FTableSize;
  if Size = 0 then
  begin
    Status := GetIfTable(nil, Size, False);
    { GetIfTable uses ERROR_INSUFFICIENT_BUFFER (not ERROR_BUFFER_OVERFLOW). }
    if (Status <> ERROR_INSUFFICIENT_BUFFER) and (Status <> ERROR_BUFFER_OVERFLOW)
      and (Status <> ERROR_SUCCESS) then
      Exit;
    if Size = 0 then
      Exit;
  end;

  GetMem(Buf, Size);
  DisplayList := TList<TNetAdapterInfo>.Create;
  try
    Status := GetIfTable(Buf, Size, False);
    if (Status = ERROR_INSUFFICIENT_BUFFER) or (Status = ERROR_BUFFER_OVERFLOW) then
    begin
      FreeMem(Buf);
      Buf := nil;
      if Size = 0 then
        Exit;
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

      if IsLoopbackAdapter(Row.dwType) then
        Continue;

      Included := not IsExcludedAdapter(Row.dwType, Descr);
      Friendly := FindFriendlyName(Row.dwIndex);
      if Friendly = '' then
        Friendly := Descr;

      Info.Index := Row.dwIndex;
      Info.FriendlyName := Friendly;
      Info.Descr := Descr;
      if Row.dwSpeed > 0 then
        Info.LinkSpeedBps := Row.dwSpeed / 8.0
      else
        Info.LinkSpeedBps := 0;
      Info.Included := Included;
      Info.IsLoopback := False;
      DisplayList.Add(Info);

      if not Included then
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
    FDisplayAdapters := DisplayList.ToArray;
    ApplyAdapterConfig;
    FHasList := True;
    FForceRefresh := False;
    FLastRefreshTick := GetTickCount;
    if MaxSpeedBits > 0 then
      FLastLinkSpeedBps := MaxSpeedBits / 8.0;
    Result := True;
  finally
    DisplayList.Free;
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

procedure TNetCollector.CopyDisplayAdapters(out AList: TArray<TNetAdapterInfo>);
begin
  AList := Copy(FDisplayAdapters);
end;

end.
