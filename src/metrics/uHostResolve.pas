unit uHostResolve;

{ Blocking IPv4 name resolution (gethostbyname), shared by the ping and tracert
  collectors. In its own unit because it needs Winapi.Winsock, which clashes
  with Winapi.IpExport (both declare in_addr / inet_ntoa) — so it cannot live
  in uIcmpApi. Callers do their own WSAStartup/WSACleanup. }

interface

{ Resolves AHost to the first IPv4 address (network byte order, as gethostbyname
  returns it). Returns False on any failure; AAddr is 0 then. }
function ResolveIPv4(const AHost: string; out AAddr: Cardinal): Boolean;

implementation

uses
  Winapi.Windows,
  Winapi.Winsock;

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

end.
