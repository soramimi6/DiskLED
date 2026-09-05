unit uIcmpApi;

{ Shared ICMP (iphlpapi.dll) declarations, used by both the ping collector
  (default TTL, no route info) and the on-demand tracert collector
  (per-hop TTL via IP_OPTION_INFORMATION). Record types and IP_STATUS
  constants come from the RTL's Winapi.IpExport. }

interface

uses
  Winapi.Windows,
  Winapi.IpExport;

type
  { Re-exported under this unit's own namespace so a consumer only needs
    uIcmpApi, not Winapi.IpExport directly — that unit declares its own
    in_addr distinct from Winapi.Winsock's, and pulling both into one unit's
    uses clause makes plain IN_ADDR/inet_ntoa usage ambiguous. }
  TIcmpEchoReply = Winapi.IpExport.TIcmpEchoReply;
  PIcmpEchoReply = Winapi.IpExport.PIcmpEchoReply;
  TIpOptionInformation = Winapi.IpExport.TIpOptionInformation;
  PIpOptionInformation = Winapi.IpExport.PIpOptionInformation;

const
  IP_SUCCESS = Winapi.IpExport.IP_SUCCESS;
  IP_TTL_EXPIRED_TRANSIT = Winapi.IpExport.IP_TTL_EXPIRED_TRANSIT;

function IcmpCreateFile: THandle; stdcall;
  external 'iphlpapi.dll' name 'IcmpCreateFile';
function IcmpCloseHandle(IcmpHandle: THandle): BOOL; stdcall;
  external 'iphlpapi.dll' name 'IcmpCloseHandle';
function IcmpSendEcho(IcmpHandle: THandle; DestinationAddress: Cardinal;
  RequestData: Pointer; RequestSize: Word; RequestOptions: PIpOptionInformation;
  ReplyBuffer: Pointer; ReplySize: DWORD; Timeout: DWORD): DWORD; stdcall;
  external 'iphlpapi.dll' name 'IcmpSendEcho';

implementation

end.
