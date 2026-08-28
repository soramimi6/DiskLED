unit uPingCollector;

{ Asynchronous ICMP echo. Worker thread; UI never blocks on send. }

interface

uses
  System.Classes,
  System.SyncObjs,
  uMetricsTypes;

type
  TPingCollector = class
  private
    FThread: TThread;
    FLock: TCriticalSection;
    FWake: TEvent;
    FStop: Boolean;
    FSending: Boolean;
    FImmediate: Boolean;
    FEnabled: Boolean;
    FAutoGateway: Boolean;
    FHost: string;
    FIntervalMs: Cardinal;
    FTimeoutMs: Cardinal;
    FFairMs: Integer;
    FSlowMs: Integer;
    FTimeoutThreshMs: Integer;
    FLastRequestTick: Cardinal;
    FRttMs: Double;
    FOk: Boolean;
    FLevel: TPingLevel;
    FLastTarget: string;
    procedure WorkerExecute;
    function ResolveIPv4(const AHost: string; out AAddr: Cardinal): Boolean;
    function TryDefaultGateway(out AHost: string): Boolean;
    function SendEcho(ADest: Cardinal; out ARttMs: Double): Boolean;
    function LevelFromRtt(AOk: Boolean; ARttMs: Double): TPingLevel;
    procedure ApplyResult(AOk: Boolean; ARttMs: Double);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ApplyConfig(AEnabled: Boolean; AIntervalSec: Integer;
      const AHost: string; AAutoGateway: Boolean;
      AFairMs, ASlowMs, ATimeoutMs: Integer);
    procedure RequestNow;
    procedure Tick;
    procedure CopyTo(var ASnap: TMetricsSnapshot);
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Winsock;

const
  CDefaultHost = 'mg6.jp';
  CIntervalMs = 300000;
  CSendTimeoutMs = 3000;
  CFairMs = 200;
  CSlowMs = 500;
  CTimeoutThreshMs = 1000;

type
  TMIBIpForwardRow = record
    dwForwardDest: DWORD;
    dwForwardMask: DWORD;
    dwForwardPolicy: DWORD;
    dwForwardNextHop: DWORD;
    dwForwardIfIndex: DWORD;
    dwForwardType: DWORD;
    dwForwardProto: DWORD;
    dwForwardAge: DWORD;
    dwForwardNextHopAS: DWORD;
    dwForwardMetric1: DWORD;
    dwForwardMetric2: DWORD;
    dwForwardMetric3: DWORD;
    dwForwardMetric4: DWORD;
    dwForwardMetric5: DWORD;
  end;

  PMIBIpForwardTable = ^TMIBIpForwardTable;
  TMIBIpForwardTable = record
    dwNumEntries: DWORD;
    table: array[0..0] of TMIBIpForwardRow;
  end;

function GetIpForwardTable(pIpForwardTable: Pointer; var pdwSize: ULONG;
  bOrder: BOOL): DWORD; stdcall; external 'iphlpapi.dll' name 'GetIpForwardTable';

type
  TIcmpEchoReply = record
    Address: Cardinal;
    Status: Cardinal;
    RoundTripTime: Cardinal;
    DataSize: Word;
    Reserved: Word;
    Data: Pointer;
    Options: record
      Ttl: Byte;
      Tos: Byte;
      Flags: Byte;
      OptionsSize: Byte;
      OptionsData: PAnsiChar;
    end;
  end;
  PIcmpEchoReply = ^TIcmpEchoReply;

function IcmpCreateFile: THandle; stdcall; external 'iphlpapi.dll' name 'IcmpCreateFile';
function IcmpCloseHandle(IcmpHandle: THandle): BOOL; stdcall;
  external 'iphlpapi.dll' name 'IcmpCloseHandle';
function IcmpSendEcho(IcmpHandle: THandle; DestinationAddress: Cardinal;
  RequestData: Pointer; RequestSize: Word; RequestOptions: Pointer;
  ReplyBuffer: Pointer; ReplySize: DWORD; Timeout: DWORD): DWORD; stdcall;
  external 'iphlpapi.dll' name 'IcmpSendEcho';

type
  TPingWorker = class(TThread)
  private
    FOwner: TPingCollector;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TPingCollector);
  end;

constructor TPingWorker.Create(AOwner: TPingCollector);
begin
  FOwner := AOwner;
  inherited Create(False);
  FreeOnTerminate := False;
end;

procedure TPingWorker.Execute;
begin
  FOwner.WorkerExecute;
end;

constructor TPingCollector.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  FStop := False;
  FSending := False;
  FImmediate := False;
  FEnabled := True;
  FAutoGateway := False;
  FHost := CDefaultHost;
  FIntervalMs := CIntervalMs;
  FTimeoutMs := CSendTimeoutMs;
  FFairMs := CFairMs;
  FSlowMs := CSlowMs;
  FTimeoutThreshMs := CTimeoutThreshMs;
  FLastRequestTick := 0;
  FRttMs := 0;
  FOk := False;
  FLevel := plTimeout;
  FThread := TPingWorker.Create(Self);
end;

destructor TPingCollector.Destroy;
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

procedure TPingCollector.ApplyConfig(AEnabled: Boolean; AIntervalSec: Integer;
  const AHost: string; AAutoGateway: Boolean;
  AFairMs, ASlowMs, ATimeoutMs: Integer);
begin
  FLock.Enter;
  try
    FEnabled := AEnabled;
    if AIntervalSec < 300 then
      AIntervalSec := 300;
    FIntervalMs := Cardinal(AIntervalSec) * 1000;
    if Trim(AHost) = '' then
      FHost := CDefaultHost
    else
      FHost := Trim(AHost);
    FLastTarget := '';
    FAutoGateway := AAutoGateway;
    FFairMs := AFairMs;
    FSlowMs := ASlowMs;
    FTimeoutThreshMs := ATimeoutMs;
    if not FEnabled then
    begin
      FOk := False;
      FRttMs := 0;
      FLevel := plTimeout;
      FImmediate := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TPingCollector.RequestNow;
begin
  FLock.Enter;
  try
    if not FEnabled then
    begin
      FOk := False;
      FRttMs := 0;
      FLevel := plTimeout;
      Exit;
    end;
    FImmediate := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TPingCollector.Tick;
var
  NowTick: Cardinal;
  Due: Boolean;
begin
  NowTick := GetTickCount;
  FLock.Enter;
  try
    if (not FEnabled) or FSending or FImmediate then
      Due := False
    else if FLastRequestTick = 0 then
      Due := True
    else
      Due := (NowTick - FLastRequestTick) >= FIntervalMs;
    if Due then
      FImmediate := True;
  finally
    FLock.Leave;
  end;
  if Due then
    FWake.SetEvent;
end;

procedure TPingCollector.CopyTo(var ASnap: TMetricsSnapshot);
begin
  FLock.Enter;
  try
    ASnap.PingPending := FSending;
    ASnap.PingRttMs := FRttMs;
    ASnap.PingOk := FOk;
    ASnap.PingLevel := FLevel;
    ASnap.PingEnabled := FEnabled;
    if FLastTarget <> '' then
      ASnap.PingTarget := FLastTarget
    else
      ASnap.PingTarget := FHost;
  finally
    FLock.Leave;
  end;
end;

function TPingCollector.LevelFromRtt(AOk: Boolean; ARttMs: Double): TPingLevel;
begin
  if (not AOk) or (ARttMs >= FTimeoutThreshMs) then
    Exit(plTimeout);
  if ARttMs >= FSlowMs then
    Exit(plSlow);
  if ARttMs >= FFairMs then
    Exit(plFair);
  Result := plNormal;
end;

procedure TPingCollector.ApplyResult(AOk: Boolean; ARttMs: Double);
begin
  FLock.Enter;
  try
    FOk := AOk;
    FRttMs := ARttMs;
    FLevel := LevelFromRtt(AOk, ARttMs);
    FSending := False;
  finally
    FLock.Leave;
  end;
end;

function TPingCollector.TryDefaultGateway(out AHost: string): Boolean;
var
  Size: ULONG;
  Buf: Pointer;
  Table: PMIBIpForwardTable;
  Row: TMIBIpForwardRow;
  i: Integer;
  Addr: IN_ADDR;
begin
  AHost := '';
  Result := False;
  Size := 0;
  if GetIpForwardTable(nil, Size, True) <> ERROR_INSUFFICIENT_BUFFER then
    Exit;
  GetMem(Buf, Size);
  try
    if GetIpForwardTable(Buf, Size, True) <> NO_ERROR then
      Exit;
    Table := PMIBIpForwardTable(Buf);
    for i := 0 to Integer(Table.dwNumEntries) - 1 do
    begin
      Move(Pointer(NativeUInt(@Table.table[0]) + NativeUInt(i) * SizeOf(TMIBIpForwardRow))^,
        Row, SizeOf(Row));
      if (Row.dwForwardDest = 0) and (Row.dwForwardMask = 0) and
        (Row.dwForwardNextHop <> 0) then
      begin
        Addr.S_addr := Row.dwForwardNextHop;
        AHost := string(inet_ntoa(Addr));
        Result := AHost <> '';
        Exit;
      end;
    end;
  finally
    FreeMem(Buf);
  end;
end;

function TPingCollector.ResolveIPv4(const AHost: string; out AAddr: Cardinal): Boolean;
var
  HostEnt: PHostEnt;
  AnsiHost: AnsiString;
begin
  AAddr := 0;
  Result := False;
  AnsiHost := AnsiString(AHost);
  HostEnt := gethostbyname(PAnsiChar(AnsiHost));
  if (HostEnt = nil) or (HostEnt^.h_addrtype <> AF_INET) or (HostEnt^.h_length <> 4) then
    Exit;
  if (HostEnt^.h_addr_list = nil) or (HostEnt^.h_addr_list^ = nil) then
    Exit;
  AAddr := PCardinal(HostEnt^.h_addr_list^)^;
  Result := AAddr <> 0;
end;

function TPingCollector.SendEcho(ADest: Cardinal; out ARttMs: Double): Boolean;
var
  H: THandle;
  Req: array[0..31] of Byte;
  Reply: array[0..255] of Byte;
  Replies: DWORD;
  Echo: PIcmpEchoReply;
begin
  ARttMs := 0;
  Result := False;
  H := IcmpCreateFile;
  if (H = 0) or (H = INVALID_HANDLE_VALUE) then
    Exit;
  try
    FillChar(Req, SizeOf(Req), $5A);
    FillChar(Reply, SizeOf(Reply), 0);
    Replies := IcmpSendEcho(H, ADest, @Req[0], SizeOf(Req), nil,
      @Reply[0], SizeOf(Reply), FTimeoutMs);
    if Replies = 0 then
      Exit;
    Echo := PIcmpEchoReply(@Reply[0]);
    if Echo^.Status <> 0 then
      Exit;
    ARttMs := Echo^.RoundTripTime;
    Result := True;
  finally
    IcmpCloseHandle(H);
  end;
end;

procedure TPingCollector.WorkerExecute;
var
  DoSend: Boolean;
  Host: string;
  PreferGw: Boolean;
  Gw: string;
  Addr: Cardinal;
  Ok: Boolean;
  Rtt: Double;
  WSAData: TWSAData;
  WSAOk: Boolean;
begin
  WSAOk := WSAStartup($0202, WSAData) = 0;
  try
    while True do
    begin
      FWake.WaitFor(INFINITE);

      PreferGw := False;
      Host := '';
      FLock.Enter;
      try
        if FStop then
          Break;
        DoSend := FEnabled and FImmediate and (not FSending);
        if DoSend then
        begin
          FImmediate := False;
          FSending := True;
          FLastRequestTick := GetTickCount;
          PreferGw := FAutoGateway;
          Host := FHost;
        end
        else
        begin
          if (not FEnabled) and FImmediate then
            FImmediate := False;
          DoSend := False;
        end;
      finally
        FLock.Leave;
      end;

      if not DoSend then
        Continue;

      if PreferGw and TryDefaultGateway(Gw) then
        Host := Gw;

      FLock.Enter;
      try
        FLastTarget := Host;
      finally
        FLock.Leave;
      end;

      Ok := False;
      Rtt := 0;
      try
        if WSAOk and ResolveIPv4(Host, Addr) then
          Ok := SendEcho(Addr, Rtt);
      except
        Ok := False;
        Rtt := 0;
      end;
      ApplyResult(Ok, Rtt);
    end;
  finally
    if WSAOk then
      WSACleanup;
  end;
end;

end.
