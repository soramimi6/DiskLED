unit uTracertCollector;

{ On-demand traceroute. Independent of the periodic ping worker: runs a
  fresh anonymous worker thread only when explicitly requested (window open
  or its refresh button), never on a timer. The target host is passed in by
  the caller (TMetricsCollector.CurrentPingTarget forwards TPingCollector's
  already-resolved target), so gateway-detection logic isn't duplicated.

  Hops are reported one at a time, nearest-first, as tracert.exe does: each
  TTL's echo completes before the next is sent, so OnHop already fires in
  order. Reverse DNS never blocks that loop — it runs on its own fire-and-
  forget thread per hop and reports back via OnHostName whenever it resolves
  (or never, if it doesn't), matching the hop up by TTL. }

interface

uses
  System.Classes;

type
  TTracertHop = record
    Ttl: Integer;
    Ip: string;
    HostName: string;
    RttMs: Double;
    Ok: Boolean; { False: no reply at all within the per-hop timeout }
  end;

  TTracertResult = record
    TargetHost: string;
    TargetIp: string;
    HopCount: Integer;
    TotalMs: Double;
    Completed: Boolean; { True: destination reached; False: gave up }
  end;

  TTracertHopEvent = procedure(const AHop: TTracertHop) of object;
  TTracertHostNameEvent = procedure(ATtl: Integer; const AHostName: string) of object;
  TTracertCompleteEvent = procedure(const AResult: TTracertResult) of object;

  TTracertCollector = class
  private
    FOnHop: TTracertHopEvent;
    FOnHostName: TTracertHostNameEvent;
    FOnComplete: TTracertCompleteEvent;
    FRunning: Boolean;
    FGeneration: Integer;
    procedure DoHop(const AHop: TTracertHop);
    procedure DoHostName(ATtl: Integer; const AHostName: string);
    procedure DoComplete(const AResult: TTracertResult);
  public
    procedure RunAsync(const AHost: string);
    property Running: Boolean read FRunning;
    property OnHop: TTracertHopEvent read FOnHop write FOnHop;
    property OnHostName: TTracertHostNameEvent read FOnHostName write FOnHostName;
    property OnComplete: TTracertCompleteEvent read FOnComplete write FOnComplete;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  Winapi.Winsock,
  uIcmpApi;

const
  CMaxHops = 30;
  CMaxConsecutiveTimeouts = 5;
  CHopTimeoutMs = 1000;

function ResolveIPv4(const AHost: string; out AAddr: Cardinal): Boolean;
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

{ Fire-and-forget: never blocks the caller. Reports back via AOnDone (queued
  to the main thread) only if it resolves to a name; if the OS resolver
  never answers, the thread just quietly runs out and self-frees. AOnDone is
  a plain closure (not a TTracertCollector method) so RunAsync can wrap it
  with its own generation check — this lookup can easily still be in flight
  after a later run has already started (e.g. window closed and reopened). }
procedure StartReverseLookup(AAddr: Cardinal; ATtl: Integer;
  AOnDone: TProc<Integer, string>);
begin
  TThread.CreateAnonymousThread(
    procedure
    var
      SockAddr: TSockAddrIn;
      Buf: array[0..255] of WideChar;
      NameText: string;
    begin
      FillChar(SockAddr, SizeOf(SockAddr), 0);
      SockAddr.sin_family := AF_INET;
      SockAddr.sin_addr.S_addr := AAddr;
      FillChar(Buf, SizeOf(Buf), 0);
      NameText := '';
      if GetNameInfoW(@SockAddr, SizeOf(SockAddr), @Buf[0], Length(Buf), nil, 0, 0) = 0 then
        NameText := Buf;
      if (NameText <> '') and Assigned(AOnDone) then
        TThread.Queue(nil, procedure begin AOnDone(ATtl, NameText); end);
    end).Start;
end;

{ TThread.Queue's closure captures locals by reference, not by value: if we
  captured the loop's own Hop variable directly, every queued callback would
  share that single mutable storage and could all fire with whatever hop the
  loop had reached by the time the main thread got to them. Routing through
  a helper whose own AHop parameter is copied fresh on each call sidesteps
  that — each queued closure captures its own call's parameter, not a
  variable shared with later iterations. }
procedure QueueHopNotify(ASelf: TTracertCollector; const AHop: TTracertHop);
begin
  TThread.Queue(nil, procedure begin ASelf.DoHop(AHop); end);
end;

function SendEchoWithTtl(AIcmp: THandle; ADest: Cardinal; ATtl: Byte;
  out AAddr: Cardinal; out ARttMs: Double; out AReached: Boolean): Boolean;
var
  Req: array[0..31] of Byte;
  Reply: array[0..255] of Byte;
  Replies: DWORD;
  Echo: PIcmpEchoReply;
  Opts: TIpOptionInformation;
begin
  AAddr := 0;
  ARttMs := 0;
  AReached := False;
  Result := False;
  FillChar(Opts, SizeOf(Opts), 0);
  Opts.Ttl := ATtl;
  FillChar(Req, SizeOf(Req), $5A);
  FillChar(Reply, SizeOf(Reply), 0);
  Replies := IcmpSendEcho(AIcmp, ADest, @Req[0], SizeOf(Req), @Opts,
    @Reply[0], SizeOf(Reply), CHopTimeoutMs);
  if Replies = 0 then
    Exit; { no response at all from this hop }
  Echo := PIcmpEchoReply(@Reply[0]);
  AAddr := Echo^.Address;
  ARttMs := Echo^.RoundTripTime;
  AReached := Echo^.Status = IP_SUCCESS;
  Result := AReached or (Echo^.Status = IP_TTL_EXPIRED_TRANSIT) or (AAddr <> 0);
end;

procedure TTracertCollector.DoHop(const AHop: TTracertHop);
begin
  if Assigned(FOnHop) then
    FOnHop(AHop);
end;

procedure TTracertCollector.DoHostName(ATtl: Integer; const AHostName: string);
begin
  if Assigned(FOnHostName) then
    FOnHostName(ATtl, AHostName);
end;

procedure TTracertCollector.DoComplete(const AResult: TTracertResult);
begin
  FRunning := False;
  if Assigned(FOnComplete) then
    FOnComplete(AResult);
end;

procedure TTracertCollector.RunAsync(const AHost: string);
var
  Host: string;
  Gen: Integer;
begin
  if FRunning then
    Exit;
  FRunning := True;
  Inc(FGeneration);
  Gen := FGeneration;
  Host := AHost;

  TThread.CreateAnonymousThread(
    procedure
    var
      WSAOk: Boolean;
      WSAData: TWSAData;
      Dest: Cardinal;
      Icmp: THandle;
      Ttl: Byte;
      ConsecutiveTimeouts: Integer;
      HopAddr: Cardinal;
      HopRtt: Double;
      Reached: Boolean;
      StartTick: Cardinal;
      Res: TTracertResult;
      Hop: TTracertHop;
      HopCount: Integer;
    begin
      Res := Default(TTracertResult);
      Res.TargetHost := Host;
      StartTick := GetTickCount;
      HopCount := 0;
      WSAOk := WSAStartup($0202, WSAData) = 0;
      try
        try
          if (not WSAOk) or (Host = '') or (not ResolveIPv4(Host, Dest)) then
            Exit;
          Res.TargetIp := AddrToStr(Dest);

          Icmp := IcmpCreateFile;
          if (Icmp = 0) or (Icmp = INVALID_HANDLE_VALUE) then
            Exit;
          try
            ConsecutiveTimeouts := 0;
            Ttl := 1;
            while Ttl <= CMaxHops do
            begin
              if SendEchoWithTtl(Icmp, Dest, Ttl, HopAddr, HopRtt, Reached) then
              begin
                ConsecutiveTimeouts := 0;
                Inc(HopCount);
                Hop.Ttl := Ttl;
                Hop.Ip := AddrToStr(HopAddr);
                Hop.RttMs := HopRtt;
                Hop.Ok := True;
                Hop.HostName := ''; { resolved asynchronously; reported via OnHostName }
                QueueHopNotify(Self, Hop);
                StartReverseLookup(HopAddr, Ttl,
                  procedure(AResolvedTtl: Integer; AName: string)
                  begin
                    if Gen = FGeneration then
                      DoHostName(AResolvedTtl, AName);
                  end);
                if Reached then
                begin
                  Res.Completed := True;
                  Break;
                end;
              end
              else
              begin
                Inc(ConsecutiveTimeouts);
                Inc(HopCount);
                Hop.Ttl := Ttl;
                Hop.Ip := '';
                Hop.HostName := '';
                Hop.RttMs := 0;
                Hop.Ok := False;
                QueueHopNotify(Self, Hop);
                if ConsecutiveTimeouts >= CMaxConsecutiveTimeouts then
                  Break;
              end;
              Inc(Ttl);
            end;
          finally
            IcmpCloseHandle(Icmp);
          end;
          Res.HopCount := HopCount;
          Res.TotalMs := GetTickCount - StartTick;
        except
          { Report completion with whatever summary was gathered so far. }
        end;
      finally
        if WSAOk then
          WSACleanup;
        TThread.Queue(nil, procedure begin DoComplete(Res); end);
      end;
    end).Start;
end;

end.
