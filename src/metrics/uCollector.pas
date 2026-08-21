unit uCollector;

interface

uses
  uMetricsTypes,
  uCpuCollector,
  uMemCollector,
  uDiskCollector,
  uNetCollector,
  uPingCollector;

type
  TMetricsCollector = class
  private
    FCpu: TCpuCollector;
    FMem: TMemCollector;
    FDisk: TDiskCollector;
    FNet: TNetCollector;
    FPing: TPingCollector;
  public
    constructor Create;
    destructor Destroy; override;
    function Collect: TMetricsSnapshot;
    procedure RequestPing;
    procedure TickPing;
    procedure ApplyPingSettings(AEnabled: Boolean; AIntervalSec: Integer;
      const AHost: string; AAutoGateway: Boolean;
      AFairMs, ASlowMs, ATimeoutMs: Integer);
  end;

implementation

uses
  Winapi.Windows;

constructor TMetricsCollector.Create;
begin
  inherited Create;
  FCpu := TCpuCollector.Create;
  FMem := TMemCollector.Create;
  FDisk := TDiskCollector.Create;
  FNet := TNetCollector.Create;
  FPing := TPingCollector.Create;
end;

destructor TMetricsCollector.Destroy;
begin
  FPing.Free;
  FNet.Free;
  FDisk.Free;
  FMem.Free;
  FCpu.Free;
  inherited;
end;

function TMetricsCollector.Collect: TMetricsSnapshot;
begin
  Result := Default(TMetricsSnapshot);
  try
    Result.CpuUsage := FCpu.Sample;
  except
    Result.CpuUsage := 0;
  end;
  try
    FMem.Sample(Result.MemUsage, Result.SwapUsage);
  except
    Result.MemUsage := 0;
    Result.SwapUsage := 0;
  end;
  try
    FDisk.Sample(Result.DiskReadBps, Result.DiskWriteBps);
  except
    Result.DiskReadBps := 0;
    Result.DiskWriteBps := 0;
  end;
  try
    FNet.Sample(Result.NetInBps, Result.NetOutBps, Result.NetLinkSpeedBps);
  except
    Result.NetInBps := 0;
    Result.NetOutBps := 0;
    Result.NetLinkSpeedBps := 0;
  end;
  FPing.CopyTo(Result);
  Result.TickMs := GetTickCount;
end;

procedure TMetricsCollector.RequestPing;
begin
  FPing.RequestNow;
end;

procedure TMetricsCollector.TickPing;
begin
  FPing.Tick;
end;

procedure TMetricsCollector.ApplyPingSettings(AEnabled: Boolean; AIntervalSec: Integer;
  const AHost: string; AAutoGateway: Boolean;
  AFairMs, ASlowMs, ATimeoutMs: Integer);
begin
  FPing.ApplyConfig(AEnabled, AIntervalSec, AHost, AAutoGateway,
    AFairMs, ASlowMs, ATimeoutMs);
end;

end.
