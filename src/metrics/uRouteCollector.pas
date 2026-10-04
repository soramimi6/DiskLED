unit uRouteCollector;

{ Route measurement for the dashboard's Ping/route page (PLANNED-3.3.0 item 14).

  The page shows how the round trip to the target splits over the path's
  segments, so per-hop RTTs have to be comparable with each other: one
  measurement is three rounds, and each round probes every TTL at nearly the
  same moment (IcmpSendEcho2, staggered ~20 ms so routers' ICMP rate limits
  don't eat the replies) instead of tracert's one-TTL-after-another. Each hop
  is summarised by the median of its three RTTs, plus min/avg/max, jitter and
  loss.

  Segment delay. A router often answers its own TTL-expired probes slowly
  (control-plane work) while forwarding traffic at full speed, so a hop can
  show a large RTT that later hops don't carry. The delay that really persists
  to a hop is the smallest median among it and every hop after it
  (EffectiveMs, non-decreasing along the path); the segment is the step from
  the previous hop's EffectiveMs, and anything above it is that router's own
  reply delay (ExcessMs), shown differently.

  Runs only while the page is shown (SetActive), on demand (RunNow, and once
  on activation) and optionally every N minutes. Nothing is sent otherwise.
  Reverse DNS runs per new address on fire-and-forget threads into a shared,
  reference-counted name cache, so a lookup finishing after this collector is
  freed touches nothing that's gone. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs;

type
  TRouteReplyKind = (rkNone, rkTtlExpired, rkReached, rkNetUnreachable,
    rkHostUnreachable, rkProtocolUnreachable, rkPortUnreachable, rkOther);

  TRouteAddrClass = (acUnknown, acLan, acCgnat, acLinkLocal, acLoopback,
    acGlobal);

  TRouteHop = record
    Ttl: Integer;
    { Most frequent replying address over the rounds; '' when none replied.
      OtherAddrs lists any others (the path differed between rounds). }
    Addr: string;
    OtherAddrs: TArray<string>;
    AddrClass: TRouteAddrClass;
    Kind: TRouteReplyKind;
    { TTL of the reply packet itself (hints at the return path length). }
    ReplyTtl: Integer;
    Sent: Integer;
    Received: Integer;
    LossPct: Double;
    MinMs: Double;
    MaxMs: Double;
    AvgMs: Double;
    MedianMs: Double;
    { Mean absolute difference between consecutive replies. }
    JitterMs: Double;
    { Delay that persists to this hop (see the unit comment), the step from
      the previous replying hop, and this router's own extra reply delay. }
    EffectiveMs: Double;
    SegmentMs: Double;
    ExcessMs: Double;
    { Median change from the previous measurement at the same TTL and
      address. }
    HasPrevious: Boolean;
    DeltaMs: Double;
  end;

  TRouteResult = record
    { A measurement has finished at least once. }
    Valid: Boolean;
    Target: string;
    TargetIp: string;
    { Name resolution / ICMP setup failed (distinct from an unreachable
      target, which still lists the hops that answered). }
    Failed: Boolean;
    Reached: Boolean;
    MeasuredAt: TDateTime;
    { EffectiveMs of the last replying hop: the path's round trip. }
    TotalMs: Double;
    Hops: TArray<TRouteHop>;
  end;

  { Reverse-DNS results shared with the lookup threads (see unit comment). }
  IRouteNameCache = interface
    ['{5B3E2D41-7C0A-4F7B-9A63-2C8F4E1D6B90}']
    { False while the lookup is pending; AName = '' when it failed. }
    function TryGet(const AAddr: string; out AName: string): Boolean;
  end;

  TRouteAsInfo = record
    { 0 when the lookup failed or the address is not announced. }
    Asn: Cardinal;
    { Operator name as registered, e.g. "GIGAINFRA Softbank BB Corp., JP". }
    Name: string;
    Country: string;
  end;

  { AS lookups (Team Cymru DNS), shared with their threads like the names. }
  IRouteAsCache = interface
    ['{8E1F4C27-3A9D-4B65-B2C0-7D5E9A1F3C48}']
    { False while the lookup is pending. }
    function TryGet(const AAddr: string; out AInfo: TRouteAsInfo): Boolean;
  end;

  TRouteCollector = class
  private
    FThread: TThread;
    FLock: TCriticalSection;
    FWake: TEvent;
    FStop: Boolean;
    FActive: Boolean;
    FRunNow: Boolean;
    FRunning: Boolean;
    FIntervalMs: Cardinal;
    FTarget: string;
    FResult: TRouteResult;
    FNames: IRouteNameCache;
    FAs: IRouteAsCache;
    FLookupAs: Boolean;
    FWSAOk: Boolean;
    procedure WorkerExecute;
    function Measure(const AHost: string; out AResult: TRouteResult): Boolean;
    function StillWanted: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { True while the Ping/route page is shown. Activating measures once;
      deactivating aborts a running measurement (its partial data is dropped)
      and stops all sending. The last result is kept for display. }
    procedure SetActive(AActive: Boolean);
    { Automatic re-measurement period in minutes; 0 = off. }
    procedure SetIntervalMin(AMinutes: Integer);
    { Host to trace; picked up by the next measurement. }
    procedure SetTarget(const AHost: string);
    procedure RunNow;
    function Running: Boolean;
    procedure CopyResult(out AResult: TRouteResult);
    { Whether measurements look up the AS of global hops (an external DNS
      query per new address). Off: nothing is sent. Takes effect from the
      next measurement. }
    procedure SetLookupAs(AEnabled: Boolean);
    property Names: IRouteNameCache read FNames;
    property AsInfo: IRouteAsCache read FAs;
  end;

function RouteAddrClass(const AAddr: string): TRouteAddrClass;

implementation

uses
  System.Generics.Collections,
  System.Math,
  Winapi.Windows,
  Winapi.Winsock,
  uIcmpApi,
  uHostResolve;

const
  CMaxTtl = 30;
  CRounds = 3;
  CStaggerMs = 20;
  CReplyTimeoutMs = 1000;
  CRequestSize = 32;
  { ICMP_ECHO_REPLY + request echo + room for an IO_STATUS_BLOCK (async). }
  CReplyBufSize = SizeOf(TIcmpEchoReply) + CRequestSize + 8 + 64;

type
  TRouteNameCache = class(TInterfacedObject, IRouteNameCache)
  private
    FLock: TCriticalSection;
    FNames: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGet(const AAddr: string; out AName: string): Boolean;
    { True when AAddr was not known yet (the caller should look it up). }
    function Claim(const AAddr: string): Boolean;
    procedure Put(const AAddr, AName: string);
  end;

  TRouteWorker = class(TThread)
  private
    FOwner: TRouteCollector;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TRouteCollector);
  end;

  { One probe's outcome. }
  TProbe = record
    Replied: Boolean;
    Status: Cardinal;
    Addr: Cardinal;
    RttMs: Double;
    ReplyTtl: Integer;
  end;

const
  CPendingName = #0;

{ TRouteNameCache }

constructor TRouteNameCache.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FNames := TDictionary<string, string>.Create;
end;

destructor TRouteNameCache.Destroy;
begin
  FNames.Free;
  FLock.Free;
  inherited;
end;

function TRouteNameCache.TryGet(const AAddr: string; out AName: string): Boolean;
begin
  FLock.Enter;
  try
    Result := FNames.TryGetValue(AAddr, AName) and (AName <> CPendingName);
  finally
    FLock.Leave;
  end;
  if not Result then
    AName := '';
end;

function TRouteNameCache.Claim(const AAddr: string): Boolean;
begin
  FLock.Enter;
  try
    Result := not FNames.ContainsKey(AAddr);
    if Result then
      FNames.Add(AAddr, CPendingName);
  finally
    FLock.Leave;
  end;
end;

procedure TRouteNameCache.Put(const AAddr, AName: string);
begin
  FLock.Enter;
  try
    FNames.AddOrSetValue(AAddr, AName);
  finally
    FLock.Leave;
  end;
end;

{ helpers }

function AddrToStr(AAddr: Cardinal): string;
var
  A: TInAddr;
begin
  A.S_addr := AAddr;
  Result := string(inet_ntoa(A));
end;

function GetNameInfoW(pSockaddr: PSockAddr; SockaddrLength: Integer;
  pNodeBuffer: PWideChar; NodeBufferSize: DWORD;
  pServiceBuffer: PWideChar; ServiceBufferSize: DWORD;
  Flags: Integer): Integer; stdcall; external 'ws2_32.dll' name 'GetNameInfoW';

const
  NI_NAMEREQD = $04;

{ Resolves on its own thread into ACache; NI_NAMEREQD makes a missing PTR
  record a failure (stored as '') instead of echoing the address back. }
procedure StartReverseLookup(const ACache: IRouteNameCache; const AAddrText: string;
  AAddr: Cardinal);
var
  Cache: IRouteNameCache;
  AddrText: string;
begin
  { Locals, so the closure holds its own reference to the cache. }
  Cache := ACache;
  AddrText := AAddrText;
  TThread.CreateAnonymousThread(
    procedure
    var
      SockAddr: TSockAddrIn;
      Buf: array[0..1024] of WideChar;
      Name: string;
    begin
      FillChar(SockAddr, SizeOf(SockAddr), 0);
      SockAddr.sin_family := AF_INET;
      SockAddr.sin_addr.S_addr := AAddr;
      Name := '';
      if GetNameInfoW(@SockAddr, SizeOf(SockAddr), @Buf[0], Length(Buf), nil, 0,
        NI_NAMEREQD) = 0 then
        Name := Buf;
      (Cache as TRouteNameCache).Put(AddrText, Name);
    end).Start;
end;

function RouteAddrClass(const AAddr: string): TRouteAddrClass;
var
  Parts: TArray<string>;
  A, B: Integer;
begin
  Result := acUnknown;
  Parts := AAddr.Split(['.']);
  if (Length(Parts) <> 4) or not TryStrToInt(Parts[0], A) or
    not TryStrToInt(Parts[1], B) then
    Exit;
  if A = 10 then
    Result := acLan
  else if (A = 172) and (B >= 16) and (B <= 31) then
    Result := acLan
  else if (A = 192) and (B = 168) then
    Result := acLan
  else if (A = 100) and (B >= 64) and (B <= 127) then
    Result := acCgnat
  else if (A = 169) and (B = 254) then
    Result := acLinkLocal
  else if A = 127 then
    Result := acLoopback
  else
    Result := acGlobal;
end;

function KindOf(AStatus: Cardinal): TRouteReplyKind;
begin
  case AStatus of
    IP_SUCCESS: Result := rkReached;
    IP_TTL_EXPIRED_TRANSIT: Result := rkTtlExpired;
    IP_DEST_NET_UNREACHABLE: Result := rkNetUnreachable;
    IP_DEST_HOST_UNREACHABLE: Result := rkHostUnreachable;
    IP_DEST_PROT_UNREACHABLE: Result := rkProtocolUnreachable;
    IP_DEST_PORT_UNREACHABLE: Result := rkPortUnreachable;
  else
    Result := rkOther;
  end;
end;

function Median(const AValues: TArray<Double>): Double;
var
  V: TArray<Double>;
  N: Integer;
begin
  N := Length(AValues);
  if N = 0 then
    Exit(0);
  V := Copy(AValues);
  TArray.Sort<Double>(V);
  if Odd(N) then
    Result := V[N div 2]
  else
    Result := (V[N div 2 - 1] + V[N div 2]) / 2;
end;

{ Sends one probe per TTL in ATtls, ~CStaggerMs apart, and waits for all of
  them. Reply buffers must outlive the requests, so this always waits for
  every event before returning, even when asked to stop. }
procedure ProbeRound(AIcmp: THandle; ADest: Cardinal; AMaxTtl: Integer;
  out AProbes: TArray<TProbe>);
var
  Events: array[1..CMaxTtl] of THandle;
  Bufs: array[1..CMaxTtl] of array[0..CReplyBufSize - 1] of Byte;
  Opts: array[1..CMaxTtl] of TIpOptionInformation;
  Req: array[0..CRequestSize - 1] of Byte;
  Pending: array[1..CMaxTtl] of Boolean;
  Ttl: Integer;
  Echo: PIcmpEchoReply;
begin
  SetLength(AProbes, AMaxTtl + 1);
  FillChar(Req, SizeOf(Req), $5A);
  for Ttl := 1 to AMaxTtl do
  begin
    AProbes[Ttl] := Default(TProbe);
    Pending[Ttl] := False;
    Events[Ttl] := CreateEvent(nil, True, False, nil);
    if Events[Ttl] = 0 then
      Continue;
    FillChar(Opts[Ttl], SizeOf(Opts[Ttl]), 0);
    Opts[Ttl].Ttl := Ttl;
    FillChar(Bufs[Ttl], SizeOf(Bufs[Ttl]), 0);
    IcmpSendEcho2(AIcmp, Events[Ttl], nil, nil, ADest, @Req[0], CRequestSize,
      @Opts[Ttl], @Bufs[Ttl][0], CReplyBufSize, CReplyTimeoutMs);
    { With an event the call completes asynchronously; anything else means the
      request never went out and the event will not be signalled. }
    Pending[Ttl] := GetLastError = ERROR_IO_PENDING;
    if Ttl < AMaxTtl then
      Sleep(CStaggerMs);
  end;
  for Ttl := 1 to AMaxTtl do
  begin
    if Events[Ttl] = 0 then
      Continue;
    if Pending[Ttl] and
      (WaitForSingleObject(Events[Ttl], CReplyTimeoutMs + 500) = WAIT_OBJECT_0) and
      (IcmpParseReplies(@Bufs[Ttl][0], CReplyBufSize) > 0) then
    begin
      Echo := PIcmpEchoReply(@Bufs[Ttl][0]);
      AProbes[Ttl].Replied := True;
      AProbes[Ttl].Status := Echo^.Status;
      AProbes[Ttl].Addr := Echo^.Address;
      AProbes[Ttl].RttMs := Echo^.RoundTripTime;
      AProbes[Ttl].ReplyTtl := Echo^.Options.Ttl;
    end;
    CloseHandle(Events[Ttl]);
  end;
end;

{ AS lookup via Team Cymru's IP-to-ASN DNS service:
    TXT d.c.b.a.origin.asn.cymru.com -> "17676 | 126.0.0.0/8 | JP | apnic | 2005-01-25"
    TXT AS17676.asn.cymru.com        -> "17676 | JP | apnic | 2005-01-25 | GIGAINFRA Softbank BB Corp., JP"
  through the system resolver (DnsQuery_W), so only the hop's address leaves
  the machine, in a DNS name. }

const
  DNS_TYPE_TEXT = $0010;
  DNS_QUERY_STANDARD = 0;
  DnsFreeRecordList = 1;

type
  PDnsRecordW = ^TDnsRecordW;
  TDnsRecordW = record
    pNext: PDnsRecordW;
    pName: PWideChar;
    wType: Word;
    wDataLength: Word;
    Flags: DWORD;
    dwTtl: DWORD;
    dwReserved: DWORD;
    { DNS_TXT_DATAW: the strings follow the count in an inline array. }
    dwStringCount: DWORD;
    pStringArray: array[0..0] of PWideChar;
  end;

function DnsQuery_W(pszName: PWideChar; wType: Word; Options: DWORD;
  pExtra: Pointer; out ppQueryResults: PDnsRecordW; pReserved: Pointer): Longint;
  stdcall; external 'dnsapi.dll' name 'DnsQuery_W';
procedure DnsFree(pData: Pointer; FreeType: Integer); stdcall;
  external 'dnsapi.dll' name 'DnsFree';

type
  TRouteAsCache = class(TInterfacedObject, IRouteAsCache)
  private
    FLock: TCriticalSection;
    { Address -> info; absent = never asked, Pending = being looked up. }
    FInfo: TDictionary<string, TRouteAsInfo>;
    FPending: TDictionary<string, Boolean>;
    { ASN -> operator name and country, so each AS is named once. }
    FAsNames: TDictionary<Cardinal, TRouteAsInfo>;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGet(const AAddr: string; out AInfo: TRouteAsInfo): Boolean;
    function Claim(const AAddr: string): Boolean;
    procedure Put(const AAddr: string; const AInfo: TRouteAsInfo);
    function TryGetAsName(AAsn: Cardinal; out AInfo: TRouteAsInfo): Boolean;
    procedure PutAsName(AAsn: Cardinal; const AInfo: TRouteAsInfo);
  end;

constructor TRouteAsCache.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FInfo := TDictionary<string, TRouteAsInfo>.Create;
  FPending := TDictionary<string, Boolean>.Create;
  FAsNames := TDictionary<Cardinal, TRouteAsInfo>.Create;
end;

destructor TRouteAsCache.Destroy;
begin
  FAsNames.Free;
  FPending.Free;
  FInfo.Free;
  FLock.Free;
  inherited;
end;

function TRouteAsCache.TryGet(const AAddr: string; out AInfo: TRouteAsInfo): Boolean;
begin
  FLock.Enter;
  try
    Result := FInfo.TryGetValue(AAddr, AInfo);
  finally
    FLock.Leave;
  end;
  if not Result then
    AInfo := Default(TRouteAsInfo);
end;

function TRouteAsCache.Claim(const AAddr: string): Boolean;
begin
  FLock.Enter;
  try
    Result := not FInfo.ContainsKey(AAddr) and not FPending.ContainsKey(AAddr);
    if Result then
      FPending.Add(AAddr, True);
  finally
    FLock.Leave;
  end;
end;

procedure TRouteAsCache.Put(const AAddr: string; const AInfo: TRouteAsInfo);
begin
  FLock.Enter;
  try
    FPending.Remove(AAddr);
    FInfo.AddOrSetValue(AAddr, AInfo);
  finally
    FLock.Leave;
  end;
end;

function TRouteAsCache.TryGetAsName(AAsn: Cardinal; out AInfo: TRouteAsInfo): Boolean;
begin
  FLock.Enter;
  try
    Result := FAsNames.TryGetValue(AAsn, AInfo);
  finally
    FLock.Leave;
  end;
end;

procedure TRouteAsCache.PutAsName(AAsn: Cardinal; const AInfo: TRouteAsInfo);
begin
  FLock.Enter;
  try
    FAsNames.AddOrSetValue(AAsn, AInfo);
  finally
    FLock.Leave;
  end;
end;

{ First TXT record of AName, its strings concatenated; '' on any failure. }
function QueryTxt(const AName: string): string;
var
  Rec, P: PDnsRecordW;
  i: Integer;
  Arr: PPWideChar;
begin
  Result := '';
  Rec := nil;
  if DnsQuery_W(PWideChar(AName), DNS_TYPE_TEXT, DNS_QUERY_STANDARD, nil, Rec, nil) <> 0 then
    Exit;
  try
    P := Rec;
    while P <> nil do
    begin
      if P^.wType = DNS_TYPE_TEXT then
      begin
        Arr := @P^.pStringArray[0];
        for i := 0 to Integer(P^.dwStringCount) - 1 do
        begin
          Result := Result + string(Arr^);
          Inc(Arr);
        end;
        Exit;
      end;
      P := P^.pNext;
    end;
  finally
    if Rec <> nil then
      DnsFree(Rec, DnsFreeRecordList);
  end;
end;

{ "a | b | c" -> trimmed fields. }
function SplitBar(const AText: string): TArray<string>;
var
  i: Integer;
begin
  Result := AText.Split(['|']);
  for i := 0 to High(Result) do
    Result[i] := Trim(Result[i]);
end;

procedure StartAsLookup(const ACache: IRouteAsCache; const AAddr: string);
var
  Cache: IRouteAsCache;
  Addr: string;
begin
  Cache := ACache;
  Addr := AAddr;
  TThread.CreateAnonymousThread(
    procedure
    var
      Octets, Fields, AsnWords: TArray<string>;
      Info, Named: TRouteAsInfo;
      Asn: Integer;
      C: TRouteAsCache;
    begin
      C := Cache as TRouteAsCache;
      Info := Default(TRouteAsInfo);
      try
        Octets := Addr.Split(['.']);
        if Length(Octets) = 4 then
        begin
          Fields := SplitBar(QueryTxt(Octets[3] + '.' + Octets[2] + '.' + Octets[1] +
            '.' + Octets[0] + '.origin.asn.cymru.com'));
          { An address announced by several ASes lists them space-separated;
            the first is enough here. }
          if Length(Fields) >= 3 then
          begin
            AsnWords := Fields[0].Split([' ']);
            if (Length(AsnWords) > 0) and TryStrToInt(AsnWords[0], Asn) and (Asn > 0) then
            begin
              Info.Asn := Cardinal(Asn);
              Info.Country := Fields[2];
              if C.TryGetAsName(Info.Asn, Named) then
                Info.Name := Named.Name
              else
              begin
                Fields := SplitBar(QueryTxt('AS' + IntToStr(Asn) + '.asn.cymru.com'));
                if Length(Fields) >= 5 then
                  Info.Name := Fields[4];
                Named := Info;
                C.PutAsName(Info.Asn, Named);
              end;
            end;
          end;
        end;
      except
        Info := Default(TRouteAsInfo);
      end;
      C.Put(Addr, Info);
    end).Start;
end;

{ TRouteWorker }

constructor TRouteWorker.Create(AOwner: TRouteCollector);
begin
  FOwner := AOwner;
  inherited Create(False);
  FreeOnTerminate := False;
end;

procedure TRouteWorker.Execute;
begin
  FOwner.WorkerExecute;
end;

{ TRouteCollector }

constructor TRouteCollector.Create;
var
  WSAData: TWSAData;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FWake := TEvent.Create(nil, False, False, '');
  FNames := TRouteNameCache.Create;
  FAs := TRouteAsCache.Create;
  FWSAOk := WSAStartup($0202, WSAData) = 0;
  FThread := TRouteWorker.Create(Self);
end;

destructor TRouteCollector.Destroy;
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
  { Reverse lookups may still be running; they only touch FNames, which they
    keep alive themselves, and need Winsock only for GetNameInfoW -- the
    process-wide Winsock stays up while the app's other collectors hold it. }
  if FWSAOk then
    WSACleanup;
  FWake.Free;
  FLock.Free;
  inherited;
end;

procedure TRouteCollector.SetActive(AActive: Boolean);
begin
  FLock.Enter;
  try
    if FActive = AActive then
      Exit;
    FActive := AActive;
    { Opening the page measures once, whatever the interval. }
    if AActive then
      FRunNow := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TRouteCollector.SetIntervalMin(AMinutes: Integer);
begin
  if AMinutes < 0 then
    AMinutes := 0;
  FLock.Enter;
  try
    FIntervalMs := Cardinal(AMinutes) * 60000;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

procedure TRouteCollector.SetTarget(const AHost: string);
begin
  FLock.Enter;
  try
    FTarget := AHost;
  finally
    FLock.Leave;
  end;
end;

procedure TRouteCollector.SetLookupAs(AEnabled: Boolean);
begin
  FLock.Enter;
  try
    FLookupAs := AEnabled;
  finally
    FLock.Leave;
  end;
end;

procedure TRouteCollector.RunNow;
begin
  FLock.Enter;
  try
    FRunNow := True;
  finally
    FLock.Leave;
  end;
  FWake.SetEvent;
end;

function TRouteCollector.Running: Boolean;
begin
  FLock.Enter;
  try
    Result := FRunning;
  finally
    FLock.Leave;
  end;
end;

procedure TRouteCollector.CopyResult(out AResult: TRouteResult);
begin
  { Replaced wholesale by the worker, never edited in place. }
  FLock.Enter;
  try
    AResult := FResult;
  finally
    FLock.Leave;
  end;
end;

function TRouteCollector.StillWanted: Boolean;
begin
  FLock.Enter;
  try
    Result := FActive and not FStop;
  finally
    FLock.Leave;
  end;
end;

function TRouteCollector.Measure(const AHost: string; out AResult: TRouteResult): Boolean;
var
  Dest: Cardinal;
  Icmp: THandle;
  Rounds: array[1..CRounds] of TArray<TProbe>;
  R, Ttl, MaxTtl, LastReplied, i, j, Best, Cnt: Integer;
  Hop: TRouteHop;
  Rtts: TArray<Double>;
  AddrCount: TDictionary<Cardinal, Integer>;
  AddrKey: Cardinal;
  Prev: TRouteResult;
  PrevMap: TDictionary<Integer, TRouteHop>;
  PrevHop: TRouteHop;
  Floor, LastEff: Double;
  LookupAs: Boolean;
begin
  Result := False;
  FLock.Enter;
  try
    LookupAs := FLookupAs;
  finally
    FLock.Leave;
  end;
  AResult := Default(TRouteResult);
  AResult.Target := AHost;
  AResult.MeasuredAt := Now;
  if (not FWSAOk) or (AHost = '') or not ResolveIPv4(AHost, Dest) then
  begin
    AResult.Failed := True;
    AResult.Valid := True;
    Exit(True);
  end;
  AResult.TargetIp := AddrToStr(Dest);
  Icmp := IcmpCreateFile;
  if (Icmp = 0) or (Icmp = INVALID_HANDLE_VALUE) then
  begin
    AResult.Failed := True;
    AResult.Valid := True;
    Exit(True);
  end;
  try
    { Round 1 probes the whole TTL range to find where the target answers;
      later rounds stop there. }
    MaxTtl := CMaxTtl;
    for R := 1 to CRounds do
    begin
      if not StillWanted then
        Exit(False);
      ProbeRound(Icmp, Dest, MaxTtl, Rounds[R]);
      if R = 1 then
      begin
        LastReplied := 0;
        for Ttl := 1 to MaxTtl do
          if Rounds[1][Ttl].Replied then
          begin
            LastReplied := Ttl;
            if Rounds[1][Ttl].Status = IP_SUCCESS then
            begin
              AResult.Reached := True;
              Break;
            end;
          end;
        if LastReplied > 0 then
          MaxTtl := LastReplied;
      end;
    end;
  finally
    IcmpCloseHandle(Icmp);
  end;
  if not StillWanted then
    Exit(False);

  CopyResult(Prev);
  PrevMap := TDictionary<Integer, TRouteHop>.Create;
  AddrCount := TDictionary<Cardinal, Integer>.Create;
  try
    for PrevHop in Prev.Hops do
      PrevMap.AddOrSetValue(PrevHop.Ttl, PrevHop);
    SetLength(AResult.Hops, MaxTtl);
    for Ttl := 1 to MaxTtl do
    begin
      Hop := Default(TRouteHop);
      Hop.Ttl := Ttl;
      Rtts := nil;
      AddrCount.Clear;
      for R := 1 to CRounds do
      begin
        if Ttl > High(Rounds[R]) then
          Continue;
        Inc(Hop.Sent);
        if not Rounds[R][Ttl].Replied then
          Continue;
        Inc(Hop.Received);
        Rtts := Rtts + [Rounds[R][Ttl].RttMs];
        AddrKey := Rounds[R][Ttl].Addr;
        if AddrCount.TryGetValue(AddrKey, Cnt) then
          AddrCount[AddrKey] := Cnt + 1
        else
          AddrCount.Add(AddrKey, 1);
      end;
      if Hop.Sent > 0 then
        Hop.LossPct := (Hop.Sent - Hop.Received) * 100 / Hop.Sent;
      if Hop.Received > 0 then
      begin
        { Representative address = most frequent; kind/reply TTL from its
          first probe. }
        Best := -1;
        for AddrKey in AddrCount.Keys do
          if AddrCount[AddrKey] > Best then
          begin
            Best := AddrCount[AddrKey];
            Hop.Addr := AddrToStr(AddrKey);
          end;
        for AddrKey in AddrCount.Keys do
          if AddrToStr(AddrKey) <> Hop.Addr then
            Hop.OtherAddrs := Hop.OtherAddrs + [AddrToStr(AddrKey)];
        for R := 1 to CRounds do
          if (Ttl <= High(Rounds[R])) and Rounds[R][Ttl].Replied and
            (AddrToStr(Rounds[R][Ttl].Addr) = Hop.Addr) then
          begin
            Hop.Kind := KindOf(Rounds[R][Ttl].Status);
            Hop.ReplyTtl := Rounds[R][Ttl].ReplyTtl;
            Break;
          end;
        Hop.AddrClass := RouteAddrClass(Hop.Addr);
        Hop.MinMs := MinValue(Rtts);
        Hop.MaxMs := MaxValue(Rtts);
        Hop.AvgMs := Mean(Rtts);
        Hop.MedianMs := Median(Rtts);
        if Length(Rtts) > 1 then
        begin
          for i := 1 to High(Rtts) do
            Hop.JitterMs := Hop.JitterMs + Abs(Rtts[i] - Rtts[i - 1]);
          Hop.JitterMs := Hop.JitterMs / High(Rtts);
        end;
        if PrevMap.TryGetValue(Ttl, PrevHop) and (PrevHop.Addr = Hop.Addr) and
          (PrevHop.Received > 0) then
        begin
          Hop.HasPrevious := True;
          Hop.DeltaMs := Hop.MedianMs - PrevHop.MedianMs;
        end;
        if (Hop.AddrClass <> acUnknown) and
          (FNames as TRouteNameCache).Claim(Hop.Addr) then
          StartReverseLookup(FNames, Hop.Addr, inet_addr(PAnsiChar(AnsiString(Hop.Addr))));
        { AS lookups only when enabled, and only for global addresses (LAN /
          CGNAT ones are never announced and would leak nothing useful). }
        if LookupAs and (Hop.AddrClass = acGlobal) and
          (FAs as TRouteAsCache).Claim(Hop.Addr) then
          StartAsLookup(FAs, Hop.Addr);
      end;
      AResult.Hops[Ttl - 1] := Hop;
    end;
  finally
    AddrCount.Free;
    PrevMap.Free;
  end;

  { Persisting delay: suffix minimum of the medians (see unit comment). }
  Floor := MaxDouble;
  for i := High(AResult.Hops) downto 0 do
    if AResult.Hops[i].Received > 0 then
    begin
      Floor := Min(Floor, AResult.Hops[i].MedianMs);
      AResult.Hops[i].EffectiveMs := Floor;
      AResult.Hops[i].ExcessMs := AResult.Hops[i].MedianMs - Floor;
    end;
  LastEff := 0;
  for j := 0 to High(AResult.Hops) do
    if AResult.Hops[j].Received > 0 then
    begin
      AResult.Hops[j].SegmentMs := AResult.Hops[j].EffectiveMs - LastEff;
      LastEff := AResult.Hops[j].EffectiveMs;
    end;
  AResult.TotalMs := LastEff;
  AResult.Valid := True;
  Result := True;
end;

procedure TRouteCollector.WorkerExecute;
var
  Stop, Active, Due: Boolean;
  Interval, Wait, NowTick, LastRunTick: Cardinal;
  HasRun: Boolean;
  Host: string;
  Res: TRouteResult;
begin
  HasRun := False;
  LastRunTick := 0;
  while True do
  begin
    FLock.Enter;
    try
      Stop := FStop;
      Active := FActive;
      Interval := FIntervalMs;
      Host := FTarget;
      NowTick := GetTickCount;
      Due := FRunNow or
        (HasRun and (Interval > 0) and (NowTick - LastRunTick >= Interval));
      if Active and Due then
      begin
        FRunNow := False;
        FRunning := True;
      end;
    finally
      FLock.Leave;
    end;
    if Stop then
      Break;

    if Active and Due then
    begin
      try
        if Measure(Host, Res) then
        begin
          FLock.Enter;
          try
            { SetActive(False) may have landed at the very end; still keep
              a complete result -- it is valid, just older next time. }
            FResult := Res;
          finally
            FLock.Leave;
          end;
        end;
      except
        { Leave the previous result in place. }
      end;
      FLock.Enter;
      try
        FRunning := False;
      finally
        FLock.Leave;
      end;
      HasRun := True;
      LastRunTick := GetTickCount;
      Continue;
    end;

    if not Active then
      Wait := INFINITE
    else if (Interval > 0) and HasRun then
    begin
      NowTick := GetTickCount;
      if NowTick - LastRunTick >= Interval then
        Wait := 0
      else
        Wait := Interval - (NowTick - LastRunTick);
    end
    else
      Wait := INFINITE;
    FWake.WaitFor(Wait);
  end;
end;

end.
