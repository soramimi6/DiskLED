unit uHistoryBuffer;

{ Fixed-width history: Capacity pixels = Capacity samples (1 px = 1 update).
  Ring buffer, zero-filled and always full. Index 0 = oldest. }

interface

type
  THistorySample = record
    Cpu: Double;
    Mem: Double;
    Swap: Double;
    DiskRead: Double;
    DiskWrite: Double;
    NetIn: Double;
    NetOut: Double;
  end;

  THistoryBuffer = class
  private
    FSamples: TArray<THistorySample>;
    FCapacity: Integer;
    FHead: Integer;
    procedure FillZeros;
  public
    constructor Create(ACapacity: Integer = 80);
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
    procedure Push(const ASample: THistorySample);
    function Capacity: Integer;
    { Index 0 = oldest, Capacity-1 = newest. }
    function SampleChronological(AIndex: Integer): THistorySample;
  end;

function ZeroHistorySample: THistorySample;
procedure AccruePeak(var APeak: THistorySample; const ASample: THistorySample);

implementation

uses
  uMetricsTypes;

function ZeroHistorySample: THistorySample;
begin
  Result.Cpu := 0;
  Result.Mem := 0;
  Result.Swap := 0;
  Result.DiskRead := 0;
  Result.DiskWrite := 0;
  Result.NetIn := 0;
  Result.NetOut := 0;
end;

procedure AccruePeak(var APeak: THistorySample; const ASample: THistorySample);
begin
  if ASample.Cpu > APeak.Cpu then
    APeak.Cpu := ASample.Cpu;
  if ASample.Mem > APeak.Mem then
    APeak.Mem := ASample.Mem;
  if ASample.Swap > APeak.Swap then
    APeak.Swap := ASample.Swap;
  if ASample.DiskRead > APeak.DiskRead then
    APeak.DiskRead := ASample.DiskRead;
  if ASample.DiskWrite > APeak.DiskWrite then
    APeak.DiskWrite := ASample.DiskWrite;
  if ASample.NetIn > APeak.NetIn then
    APeak.NetIn := ASample.NetIn;
  if ASample.NetOut > APeak.NetOut then
    APeak.NetOut := ASample.NetOut;
end;

constructor THistoryBuffer.Create(ACapacity: Integer);
begin
  inherited Create;
  if ACapacity < 1 then
    ACapacity := 1;
  FCapacity := ACapacity;
  FHead := 0;
  SetLength(FSamples, FCapacity);
  FillZeros;
end;

procedure THistoryBuffer.FillZeros;
var
  i: Integer;
  Z: THistorySample;
begin
  Z := ZeroHistorySample;
  for i := 0 to FCapacity - 1 do
    FSamples[i] := Z;
  FHead := 0;
end;

procedure THistoryBuffer.Clear;
begin
  FillZeros;
end;

procedure THistoryBuffer.SetCapacity(ACapacity: Integer);
begin
  if ACapacity < 1 then
    ACapacity := 1;
  if ACapacity = FCapacity then
  begin
    FillZeros;
    Exit;
  end;
  FCapacity := ACapacity;
  SetLength(FSamples, FCapacity);
  FillZeros;
end;

procedure THistoryBuffer.Push(const ASample: THistorySample);
var
  S: THistorySample;
begin
  if FCapacity < 1 then
    Exit;
  S.Cpu := Clamp01(ASample.Cpu);
  S.Mem := Clamp01(ASample.Mem);
  S.Swap := Clamp01(ASample.Swap);
  S.DiskRead := Clamp01(ASample.DiskRead);
  S.DiskWrite := Clamp01(ASample.DiskWrite);
  S.NetIn := Clamp01(ASample.NetIn);
  S.NetOut := Clamp01(ASample.NetOut);
  FSamples[FHead] := S;
  FHead := (FHead + 1) mod FCapacity;
end;

function THistoryBuffer.Capacity: Integer;
begin
  Result := FCapacity;
end;

function THistoryBuffer.SampleChronological(AIndex: Integer): THistorySample;
begin
  if (FCapacity < 1) or (AIndex < 0) or (AIndex >= FCapacity) then
    Exit(ZeroHistorySample);
  Result := FSamples[(FHead + AIndex) mod FCapacity];
end;

end.
