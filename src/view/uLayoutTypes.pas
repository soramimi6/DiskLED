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
    { Ballistic follow for meter-kind parts only (Cpu/Mem/Swap/*Meter/Audio*).
      Every meter part's layout.cfg section states its own Kind/Strength --
      there is no shared default any more, so LED/Ping parts simply never
      read these two fields. }
    BallisticKind: TBallisticKind;
    BallisticStrength: Integer;
  end;

  TDigitStyle = (dsBitmap, dsSystem);

  TDigitValue = record
    Enabled: Boolean;
    Style: TDigitStyle;
    X: Integer;
    Y: Integer;
    Digits: Integer;
    FillZero: Boolean;
    { ValStyle=system only. }
    FontName: string;
    FontSize: Integer;
    Color: TColor;
    Bold: Boolean;
    { ValStyle=bitmap only -- each part with a bitmap readout owns its font
      sheet now, instead of sharing one mode-wide [Mode] Font=. }
    BitmapFile: string;
    FontMaskColor: TColor;
    FontTransparent: Boolean;
  end;

  TGraphStyle = (gsLine, gsBar);

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
    Style: TGraphStyle;
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
    { Max(DiskRead, DiskWrite) combined dial — see TMeterBallistics.DiskIo. }
    DiskIoMeter: TSpriteStrip;
    NetInMeter: TSpriteStrip;
    NetOutMeter: TSpriteStrip;
    { Max(NetIn, NetOut) combined dial — see TMeterBallistics.NetIo. }
    NetIoMeter: TSpriteStrip;
    Audio: TSpriteStrip;
    AudioL: TSpriteStrip;
    AudioR: TSpriteStrip;
    CpuVal: TDigitValue;
    MemVal: TDigitValue;
    SwapVal: TDigitValue;
    Graph: TGraphLayout;
  end;

function GraphMaxWidth(const AGraph: TGraphLayout): Integer;

{ Assembles a TMeterBallistics from the 12 meter parts' own BallisticKind/
  BallisticStrength -- built fresh from whichever TViewLayout (compact or
  full) is currently active, since each part carries its own ballistic
  behavior instead of it living in one shared, mode-wide record. }
function BuildMeterBallistics(const ALayout: TViewLayout): TMeterBallistics;

implementation

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

function ToParams(const AStrip: TSpriteStrip): TBallisticParams;
begin
  Result.Kind := AStrip.BallisticKind;
  Result.Strength := AStrip.BallisticStrength;
end;

function BuildMeterBallistics(const ALayout: TViewLayout): TMeterBallistics;
begin
  Result.Cpu := ToParams(ALayout.Cpu);
  Result.Mem := ToParams(ALayout.Mem);
  Result.Swap := ToParams(ALayout.Swap);
  Result.DiskRead := ToParams(ALayout.DiskReadMeter);
  Result.DiskWrite := ToParams(ALayout.DiskWriteMeter);
  Result.DiskIo := ToParams(ALayout.DiskIoMeter);
  Result.NetIn := ToParams(ALayout.NetInMeter);
  Result.NetOut := ToParams(ALayout.NetOutMeter);
  Result.NetIo := ToParams(ALayout.NetIoMeter);
  Result.Audio := ToParams(ALayout.Audio);
  Result.AudioL := ToParams(ALayout.AudioL);
  Result.AudioR := ToParams(ALayout.AudioR);
end;

end.
