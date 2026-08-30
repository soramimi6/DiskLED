unit uDashboardHistory;

{ Dashboard graph history: 8 lanes x fixed capacity ring buffer (1 Hz push). }

interface

type
  TDashboardLane = (dlCpu, dlMem, dlSwap, dlDiskRead, dlDiskWrite, dlNetIn, dlNetOut);
  TDashboardLaneSet = set of TDashboardLane;

  TDashboardSample = record
    Cpu, Mem, Swap: Single;
    DiskRead, DiskWrite: Single;
    NetIn, NetOut: Single;
  end;

  TDashboardHistory = class
  private
    FLanes: array[TDashboardLane] of TArray<Single>;
    FCapacity: Integer;
    FCount: Integer;
    FHead: Integer;
  public
    constructor Create(ACapacity: Integer = 300);
    procedure Push(const S: TDashboardSample);
    procedure Clear;
    procedure ClearLanes(const ALanes: TDashboardLaneSet);
    function Count: Integer;
    function LaneValue(ALane: TDashboardLane; AChronologicalIndex: Integer): Single;
  end;

function ZeroDashboardSample: TDashboardSample;
procedure AccrueDashboardPeak(var APeak: TDashboardSample; const S: TDashboardSample);

implementation

uses
  System.SysUtils,
  uMetricsTypes;

function ZeroDashboardSample: TDashboardSample;
begin
  FillChar(Result, SizeOf(Result), 0);
end;

procedure AccrueDashboardPeak(var APeak: TDashboardSample; const S: TDashboardSample);
begin
  if S.Cpu > APeak.Cpu then
    APeak.Cpu := S.Cpu;
  if S.Mem > APeak.Mem then
    APeak.Mem := S.Mem;
  if S.Swap > APeak.Swap then
    APeak.Swap := S.Swap;
  if S.DiskRead > APeak.DiskRead then
    APeak.DiskRead := S.DiskRead;
  if S.DiskWrite > APeak.DiskWrite then
    APeak.DiskWrite := S.DiskWrite;
  if S.NetIn > APeak.NetIn then
    APeak.NetIn := S.NetIn;
  if S.NetOut > APeak.NetOut then
    APeak.NetOut := S.NetOut;
end;

constructor TDashboardHistory.Create(ACapacity: Integer);
var
  L: TDashboardLane;
begin
  inherited Create;
  if ACapacity < 1 then
    ACapacity := 1;
  FCapacity := ACapacity;
  FCount := 0;
  FHead := 0;
  for L := Low(TDashboardLane) to High(TDashboardLane) do
    SetLength(FLanes[L], FCapacity);
end;

procedure TDashboardHistory.Push(const S: TDashboardSample);
var
  Idx: Integer;
begin
  Idx := FHead;
  FLanes[dlCpu][Idx] := Clamp01(S.Cpu);
  FLanes[dlMem][Idx] := Clamp01(S.Mem);
  FLanes[dlSwap][Idx] := Clamp01(S.Swap);
  FLanes[dlDiskRead][Idx] := Clamp01(S.DiskRead);
  FLanes[dlDiskWrite][Idx] := Clamp01(S.DiskWrite);
  FLanes[dlNetIn][Idx] := Clamp01(S.NetIn);
  FLanes[dlNetOut][Idx] := Clamp01(S.NetOut);
  FHead := (FHead + 1) mod FCapacity;
  if FCount < FCapacity then
    Inc(FCount);
end;

procedure TDashboardHistory.Clear;
var
  L: TDashboardLane;
  i: Integer;
begin
  for L := Low(TDashboardLane) to High(TDashboardLane) do
    for i := 0 to FCapacity - 1 do
      FLanes[L][i] := 0;
  FCount := 0;
  FHead := 0;
end;

procedure TDashboardHistory.ClearLanes(const ALanes: TDashboardLaneSet);
var
  L: TDashboardLane;
  i, StartIdx: Integer;
begin
  if FCount = 0 then
    Exit;
  for L := Low(TDashboardLane) to High(TDashboardLane) do
  begin
    if not (L in ALanes) then
      Continue;
    if FCount < FCapacity then
      StartIdx := 0
    else
      StartIdx := FHead;
    for i := 0 to FCount - 1 do
      FLanes[L][(StartIdx + i) mod FCapacity] := 0;
  end;
end;

function TDashboardHistory.Count: Integer;
begin
  Result := FCount;
end;

function TDashboardHistory.LaneValue(ALane: TDashboardLane;
  AChronologicalIndex: Integer): Single;
var
  StartIdx, PhysIdx: Integer;
begin
  Result := 0;
  if (AChronologicalIndex < 0) or (AChronologicalIndex >= FCount) then
    Exit;
  if FCount < FCapacity then
    StartIdx := 0
  else
    StartIdx := FHead;
  PhysIdx := (StartIdx + AChronologicalIndex) mod FCapacity;
  Result := FLanes[ALane][PhysIdx];
end;

end.
