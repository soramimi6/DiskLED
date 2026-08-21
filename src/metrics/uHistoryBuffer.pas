unit uHistoryBuffer;

{ Fixed-width history: Capacity pixels = Capacity samples (1 px = 1 update).
  Buffer is zero-filled and always full. }

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
    procedure FillZeros;
  public
    constructor Create(ACapacity: Integer = 80);
    procedure Clear;
    procedure SetCapacity(ACapacity: Integer);
    procedure Push(const ASample: THistorySample);
    function Capacity: Integer;
    { Always Length = Capacity; index 0 = oldest, Capacity-1 = newest. }
    procedure CopyChronological(out ADest: TArray<THistorySample>);
  end;

implementation

uses
  uMetricsTypes;

function ZeroSample: THistorySample;
begin
  Result.Cpu := 0;
  Result.Mem := 0;
  Result.Swap := 0;
  Result.DiskRead := 0;
  Result.DiskWrite := 0;
  Result.NetIn := 0;
  Result.NetOut := 0;
end;

constructor THistoryBuffer.Create(ACapacity: Integer);
begin
  inherited Create;
  if ACapacity < 1 then
    ACapacity := 1;
  FCapacity := ACapacity;
  SetLength(FSamples, FCapacity);
  FillZeros;
end;

procedure THistoryBuffer.FillZeros;
var
  i: Integer;
  Z: THistorySample;
begin
  Z := ZeroSample;
  for i := 0 to FCapacity - 1 do
    FSamples[i] := Z;
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
  i: Integer;
  S: THistorySample;
begin
  if FCapacity < 1 then
    Exit;
  for i := 0 to FCapacity - 2 do
    FSamples[i] := FSamples[i + 1];
  S.Cpu := Clamp01(ASample.Cpu);
  S.Mem := Clamp01(ASample.Mem);
  S.Swap := Clamp01(ASample.Swap);
  S.DiskRead := Clamp01(ASample.DiskRead);
  S.DiskWrite := Clamp01(ASample.DiskWrite);
  S.NetIn := Clamp01(ASample.NetIn);
  S.NetOut := Clamp01(ASample.NetOut);
  FSamples[FCapacity - 1] := S;
end;

function THistoryBuffer.Capacity: Integer;
begin
  Result := FCapacity;
end;

procedure THistoryBuffer.CopyChronological(out ADest: TArray<THistorySample>);
var
  i: Integer;
begin
  SetLength(ADest, FCapacity);
  for i := 0 to FCapacity - 1 do
    ADest[i] := FSamples[i];
end;

end.
