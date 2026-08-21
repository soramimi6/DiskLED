unit uMetricsTypes;

interface

type
  TPingLevel = (plTimeout, plSlow, plFair, plNormal);

  TMetricsSnapshot = record
    CpuUsage: Double;
    MemUsage: Double;
    SwapUsage: Double;
    DiskReadBps: Double;
    DiskWriteBps: Double;
    NetInBps: Double;
    NetOutBps: Double;
    NetLinkSpeedBps: Double; { Byte/s; 0 if unknown }
    PingRttMs: Double;
    PingOk: Boolean;
    PingPending: Boolean;
    PingLevel: TPingLevel;
    TickMs: Cardinal;
  end;

  TDisplayState = record
    Cpu: Double;
    Mem: Double;
    Swap: Double;
    { Digit readout (held; slower than meter bars). }
    CpuDigit: Double;
    MemDigit: Double;
    SwapDigit: Double;
    DiskRead: Double;
    DiskWrite: Double;
    NetIn: Double;
    NetOut: Double;
    DiskReadOn: Boolean;
    DiskWriteOn: Boolean;
    DiskRWOn: Boolean;
    NetInOn: Boolean;
    NetOutOn: Boolean;
    NetActivityOn: Boolean;
    PingLevel: TPingLevel;
    PingPending: Boolean;
  end;

const
  CNoiseFloorBps = 4096.0; { ignore below 4 KiB/s }

function Clamp01(const AValue: Double): Double;
function IsActiveBps(const ABps: Double): Boolean;

implementation

function Clamp01(const AValue: Double): Double;
begin
  if AValue < 0 then
    Result := 0
  else if AValue > 1 then
    Result := 1
  else
    Result := AValue;
end;

function IsActiveBps(const ABps: Double): Boolean;
begin
  Result := ABps > CNoiseFloorBps;
end;

end.
