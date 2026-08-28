unit uLayoutTypes;

interface

uses
  System.UITypes,
  Vcl.Graphics,
  uMetricsTypes;

type
  TSpriteStrip = record
    FileName: string;
    X: Integer;
    Y: Integer;
    Frames: Integer;
    Transparent: Boolean;
    MaskColor: TColor;
  end;

  TDigitStyle = (dsBitmap, dsSystem);

  TDigitValue = record
    Enabled: Boolean;
    Style: TDigitStyle;
    X: Integer;
    Y: Integer;
    Digits: Integer;
    FillZero: Boolean;
    FontName: string;
    FontSize: Integer;
    Color: TColor;
    Bold: Boolean;
  end;

  TGraphLane = record
    Enabled: Boolean;
    X: Integer;
    Y: Integer;
    W: Integer;
    H: Integer;
    Color: TColor;
  end;

  TGraphLayout = record
    Enabled: Boolean;
    Cpu: TGraphLane;
    Mem: TGraphLane;
    Swap: TGraphLane;
    DiskRead: TGraphLane;
    DiskWrite: TGraphLane;
    NetIn: TGraphLane;
    NetOut: TGraphLane;
  end;

  TViewLayout = record
    ModeId: string;
    Width: Integer;
    Height: Integer;
    Transparent: Boolean;
    MaskColor: TColor;
    BgFile: string;
    FontFile: string;
    FontMaskColor: TColor;
    FontTransparent: Boolean;
    Cpu: TSpriteStrip;
    Mem: TSpriteStrip;
    Swap: TSpriteStrip;
    Ping: TSpriteStrip;
    DiskRead: TSpriteStrip;
    DiskWrite: TSpriteStrip;
    DiskRW: TSpriteStrip;
    NetIn: TSpriteStrip;
    NetOut: TSpriteStrip;
    NetActivity: TSpriteStrip;
    NetTotal: TSpriteStrip;
    DiskReadMeter: TSpriteStrip;
    DiskWriteMeter: TSpriteStrip;
    NetInMeter: TSpriteStrip;
    NetOutMeter: TSpriteStrip;
    CpuVal: TDigitValue;
    MemVal: TDigitValue;
    SwapVal: TDigitValue;
    Graph: TGraphLayout;
    Ballistics: TMeterBallistics;
  end;

function Sprite(const AFileName: string; AX, AY, AFrames: Integer): TSpriteStrip;
function SpriteKey(const AFileName: string; AX, AY, AFrames: Integer;
  AMaskColor: TColor): TSpriteStrip;
function GraphMaxWidth(const AGraph: TGraphLayout): Integer;

implementation

function Sprite(const AFileName: string; AX, AY, AFrames: Integer): TSpriteStrip;
begin
  Result := SpriteKey(AFileName, AX, AY, AFrames, 0);
  Result.Transparent := False;
end;

function SpriteKey(const AFileName: string; AX, AY, AFrames: Integer;
  AMaskColor: TColor): TSpriteStrip;
begin
  Result.FileName := AFileName;
  Result.X := AX;
  Result.Y := AY;
  Result.Frames := AFrames;
  Result.Transparent := True;
  Result.MaskColor := AMaskColor;
end;

function GraphMaxWidth(const AGraph: TGraphLayout): Integer;
begin
  Result := 0;
  if AGraph.Cpu.Enabled and (AGraph.Cpu.W > Result) then
    Result := AGraph.Cpu.W;
  if AGraph.Mem.Enabled and (AGraph.Mem.W > Result) then
    Result := AGraph.Mem.W;
  if AGraph.Swap.Enabled and (AGraph.Swap.W > Result) then
    Result := AGraph.Swap.W;
  if AGraph.DiskRead.Enabled and (AGraph.DiskRead.W > Result) then
    Result := AGraph.DiskRead.W;
  if AGraph.DiskWrite.Enabled and (AGraph.DiskWrite.W > Result) then
    Result := AGraph.DiskWrite.W;
  if AGraph.NetIn.Enabled and (AGraph.NetIn.W > Result) then
    Result := AGraph.NetIn.W;
  if AGraph.NetOut.Enabled and (AGraph.NetOut.W > Result) then
    Result := AGraph.NetOut.W;
end;

end.
