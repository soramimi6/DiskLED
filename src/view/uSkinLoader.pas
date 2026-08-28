unit uSkinLoader;

{ Loads assets/<id>/layout.cfg into compact + optional full TViewLayout. }

interface

uses
  uLayoutTypes;

type
  TSkinModeMeta = record
    Id: string;
    Caption: string;
    Order: Integer;
    IsDefault: Boolean;
    HasFull: Boolean;
    Layout: TViewLayout;
    FullLayout: TViewLayout;
  end;

function LoadSkinLayout(const ALayoutIniPath: string; out AMeta: TSkinModeMeta): Boolean;

implementation

uses
  System.SysUtils,
  System.IniFiles,
  System.UITypes,
  Winapi.Windows,
  Vcl.Graphics,
  uAppStrings,
  uMetricsTypes;

function ParseBool(const S: string; ADefault: Boolean): Boolean;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  if V = '' then
    Exit(ADefault);
  Result := (V = '1') or (V = 'true') or (V = 'yes') or (V = 'on');
end;

function IsHexChar(C: Char): Boolean;
begin
  Result := CharInSet(C, ['0'..'9', 'A'..'F', 'a'..'f']);
end;

function ParseColor(const S: string; ADefault: TColor): TColor;
var
  V: string;
  R, G, B: Integer;
begin
  V := Trim(S);
  if V = '' then
    Exit(ADefault);
  if (Length(V) = 7) and (V[1] = '#') and
    IsHexChar(V[2]) and IsHexChar(V[3]) and IsHexChar(V[4]) and
    IsHexChar(V[5]) and IsHexChar(V[6]) and IsHexChar(V[7]) then
  begin
    R := StrToInt('$' + Copy(V, 2, 2));
    G := StrToInt('$' + Copy(V, 4, 2));
    B := StrToInt('$' + Copy(V, 6, 2));
    Result := RGB(R, G, B);
    Exit;
  end;
  if (Length(V) >= 2) and (LowerCase(Copy(V, 1, 2)) = 'cl') then
  try
    Result := StringToColor(V);
    Exit;
  except
    Result := ADefault;
    Exit;
  end;
  Result := ADefault;
end;

function ParseDigitStyle(const S: string): TDigitStyle;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  if V = 'system' then
    Result := dsSystem
  else
    Result := dsBitmap;
end;

function ParseBallisticKind(const S: string; ADefault: TBallisticKind): TBallisticKind;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  if V = 'bar' then
    Result := bkBar
  else if V = 'peak' then
    Result := bkPeak
  else if V = 'vu' then
    Result := bkVu
  else
    Result := ADefault;
end;

function ParseBallisticParams(const Raw: string; const AFallback: TBallisticParams): TBallisticParams;
var
  V: string;
  KindStr: string;
  StrStr: string;
  P: Integer;
begin
  Result := AFallback;
  V := Trim(Raw);
  if V = '' then
    Exit;
  P := Pos(',', V);
  if P > 0 then
  begin
    KindStr := Trim(Copy(V, 1, P - 1));
    StrStr := Trim(Copy(V, P + 1, MaxInt));
  end
  else
  begin
    KindStr := V;
    StrStr := '';
  end;
  if KindStr <> '' then
    Result.Kind := ParseBallisticKind(KindStr, AFallback.Kind);
  if StrStr <> '' then
    Result.Strength := ClampStrength(StrToIntDef(StrStr, AFallback.Strength));
end;

function ReadBallisticChannel(Ini: TCustomIniFile; const AKey: string;
  const AFallback: TBallisticParams): TBallisticParams;
begin
  if not Ini.ValueExists('Ballistic', AKey) then
    Exit(AFallback);
  Result := ParseBallisticParams(Ini.ReadString('Ballistic', AKey, ''), AFallback);
end;

procedure ReadBallistics(Ini: TCustomIniFile; var ALayout: TViewLayout);
var
  Def: TBallisticParams;
begin
  Def := DefaultBallisticParams;
  if Ini.ValueExists('Ballistic', 'Default') then
    Def.Kind := ParseBallisticKind(Ini.ReadString('Ballistic', 'Default', 'vu'), bkVu);
  if Ini.ValueExists('Ballistic', 'Strength') then
    Def.Strength := ClampStrength(Ini.ReadInteger('Ballistic', 'Strength', 50));

  ALayout.Ballistics.Cpu := ReadBallisticChannel(Ini, 'Cpu', Def);
  ALayout.Ballistics.Mem := ReadBallisticChannel(Ini, 'Mem', Def);
  ALayout.Ballistics.Swap := ReadBallisticChannel(Ini, 'Swap', Def);
  ALayout.Ballistics.DiskRead := ReadBallisticChannel(Ini, 'DiskReadMeter', Def);
  ALayout.Ballistics.DiskWrite := ReadBallisticChannel(Ini, 'DiskWriteMeter', Def);
  ALayout.Ballistics.NetIn := ReadBallisticChannel(Ini, 'NetInMeter', Def);
  ALayout.Ballistics.NetOut := ReadBallisticChannel(Ini, 'NetOutMeter', Def);
end;

function ReadSprite(Ini: TCustomIniFile; const ASection: string): TSpriteStrip;
var
  FileName: string;
  HasMask: Boolean;
  Mask: TColor;
begin
  Result := Default(TSpriteStrip);
  FileName := Trim(Ini.ReadString(ASection, 'File', ''));
  if FileName = '' then
    Exit;

  Result.FileName := FileName;
  Result.X := Ini.ReadInteger(ASection, 'X', 0);
  Result.Y := Ini.ReadInteger(ASection, 'Y', 0);
  Result.Frames := Ini.ReadInteger(ASection, 'Frames', 1);
  if Result.Frames < 1 then
    Result.Frames := 1;

  HasMask := Trim(Ini.ReadString(ASection, 'MaskColor', '')) <> '';
  if Ini.ValueExists(ASection, 'Transparent') then
    Result.Transparent := ParseBool(Ini.ReadString(ASection, 'Transparent', ''), HasMask)
  else
    Result.Transparent := HasMask;

  if Result.Transparent then
  begin
    Mask := ParseColor(Ini.ReadString(ASection, 'MaskColor', ''), clBlack);
    Result.MaskColor := Mask;
  end;
end;

function ReadDigitValue(Ini: TCustomIniFile; const ASection: string): TDigitValue;
begin
  Result := Default(TDigitValue);
  Result.Enabled := ParseBool(Ini.ReadString(ASection, 'ValSW', '0'), False);
  Result.Style := ParseDigitStyle(Ini.ReadString(ASection, 'ValStyle', 'bitmap'));
  Result.X := Ini.ReadInteger(ASection, 'ValX', 0);
  Result.Y := Ini.ReadInteger(ASection, 'ValY', 0);
  Result.Digits := Ini.ReadInteger(ASection, 'ValB', 3);
  if Result.Digits < 1 then
    Result.Digits := 1;
  Result.FillZero := ParseBool(Ini.ReadString(ASection, 'ValFZ', '0'), False);
  Result.FontName := Trim(Ini.ReadString(ASection, 'ValFont', ''));
  Result.FontSize := Ini.ReadInteger(ASection, 'ValFontSize', 9);
  if Result.FontSize < 1 then
    Result.FontSize := 9;
  Result.Color := ParseColor(Ini.ReadString(ASection, 'ValColor', ''), clBlack);
  Result.Bold := ParseBool(Ini.ReadString(ASection, 'ValBold', '0'), False);
end;

procedure ReadParts(Ini: TCustomIniFile; var ALayout: TViewLayout);
var
  FontMaskRaw: string;
begin
  ALayout.Transparent := ParseBool(Ini.ReadString('Mode', 'Transparent', '1'), True);
  ALayout.MaskColor := ParseColor(Ini.ReadString('Mode', 'MaskColor', ''), clBlack);
  ALayout.BgFile := Trim(Ini.ReadString('Mode', 'Bg', ''));
  ALayout.Width := Ini.ReadInteger('Mode', 'Width', 0);
  ALayout.Height := Ini.ReadInteger('Mode', 'Height', 0);
  ALayout.FontFile := Trim(Ini.ReadString('Mode', 'Font', ''));
  FontMaskRaw := Trim(Ini.ReadString('Mode', 'FontMaskColor', ''));
  ALayout.FontTransparent := FontMaskRaw <> '';
  if ALayout.FontTransparent then
    ALayout.FontMaskColor := ParseColor(FontMaskRaw, clBlack)
  else
    ALayout.FontMaskColor := clBlack;

  ALayout.Cpu := ReadSprite(Ini, 'Cpu');
  ALayout.Mem := ReadSprite(Ini, 'Mem');
  ALayout.Swap := ReadSprite(Ini, 'Swap');
  ALayout.Ping := ReadSprite(Ini, 'Ping');
  ALayout.DiskRead := ReadSprite(Ini, 'DiskRead');
  ALayout.DiskWrite := ReadSprite(Ini, 'DiskWrite');
  ALayout.DiskRW := ReadSprite(Ini, 'DiskRW');
  ALayout.NetIn := ReadSprite(Ini, 'NetIn');
  ALayout.NetOut := ReadSprite(Ini, 'NetOut');
  ALayout.NetActivity := ReadSprite(Ini, 'NetActivity');
  ALayout.NetTotal := ReadSprite(Ini, 'NetTotal');
  ALayout.DiskReadMeter := ReadSprite(Ini, 'DiskReadMeter');
  ALayout.DiskWriteMeter := ReadSprite(Ini, 'DiskWriteMeter');
  ALayout.NetInMeter := ReadSprite(Ini, 'NetInMeter');
  ALayout.NetOutMeter := ReadSprite(Ini, 'NetOutMeter');
  ALayout.CpuVal := ReadDigitValue(Ini, 'Cpu');
  ALayout.MemVal := ReadDigitValue(Ini, 'Mem');
  ALayout.SwapVal := ReadDigitValue(Ini, 'Swap');
  ALayout.Graph := Default(TGraphLayout);
  ReadBallistics(Ini, ALayout);
end;

function ReadGraphLane(Ini: TCustomIniFile; const AKey, AColorKey: string;
  ADefaultColor: TColor): TGraphLane;
var
  Raw: string;
  P1, P2, P3: Integer;
begin
  Result := Default(TGraphLane);
  Raw := Trim(Ini.ReadString('Graph', AKey, ''));
  if Raw = '' then
    Exit;
  P1 := Pos(',', Raw);
  if P1 <= 0 then
    Exit;
  Result.X := StrToIntDef(Trim(Copy(Raw, 1, P1 - 1)), 0);
  Delete(Raw, 1, P1);
  P2 := Pos(',', Raw);
  if P2 <= 0 then
    Exit;
  Result.Y := StrToIntDef(Trim(Copy(Raw, 1, P2 - 1)), 0);
  Delete(Raw, 1, P2);
  P3 := Pos(',', Raw);
  if P3 <= 0 then
    Exit;
  Result.W := StrToIntDef(Trim(Copy(Raw, 1, P3 - 1)), 0);
  Result.H := StrToIntDef(Trim(Copy(Raw, P3 + 1, MaxInt)), 0);
  if (Result.W <= 0) or (Result.H <= 0) then
    Exit;
  Result.Color := ParseColor(Ini.ReadString('Graph', AColorKey, ''), ADefaultColor);
  Result.Enabled := True;
end;

function ReadGraph(Ini: TCustomIniFile): TGraphLayout;
var
  StyleRaw: string;
begin
  Result := Default(TGraphLayout);
  StyleRaw := LowerCase(Trim(Ini.ReadString('Graph', 'Style', '')));
  if StyleRaw = 'bar' then
    Result.Style := gsBar
  else
    Result.Style := gsLine;
  Result.Cpu := ReadGraphLane(Ini, 'Cpu', 'CpuColor', RGB(0, 0, 0));
  Result.Mem := ReadGraphLane(Ini, 'Mem', 'MemColor', RGB(0, 0, 0));
  Result.Swap := ReadGraphLane(Ini, 'Swap', 'SwapColor', RGB(0, 0, 0));
  Result.DiskRead := ReadGraphLane(Ini, 'DiskRead', 'DiskReadColor', RGB(0, 0, 0));
  Result.DiskWrite := ReadGraphLane(Ini, 'DiskWrite', 'DiskWriteColor', RGB(0, 0, 0));
  Result.NetIn := ReadGraphLane(Ini, 'NetIn', 'NetInColor', RGB(0, 0, 0));
  Result.NetOut := ReadGraphLane(Ini, 'NetOut', 'NetOutColor', RGB(0, 0, 0));
  Result.Enabled := Result.Cpu.Enabled or Result.Mem.Enabled or Result.Swap.Enabled or
    Result.DiskRead.Enabled or Result.DiskWrite.Enabled or
    Result.NetIn.Enabled or Result.NetOut.Enabled;
end;

function LoadSkinLayout(const ALayoutIniPath: string; out AMeta: TSkinModeMeta): Boolean;
var
  Ini: TMemIniFile;
  FolderName: string;
  FullBg: string;
  FullW, FullH: Integer;
begin
  Result := False;
  AMeta := Default(TSkinModeMeta);
  if not FileExists(ALayoutIniPath) then
    Exit;

  Ini := TMemIniFile.Create(ALayoutIniPath);
  try
    FolderName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(ALayoutIniPath)));
    AMeta.Id := Trim(Ini.ReadString('Mode', 'Id', FolderName));
    if AMeta.Id = '' then
      AMeta.Id := FolderName;
    AMeta.Caption := Trim(Ini.ReadString('Mode', 'Caption', AMeta.Id));
    AMeta.Order := Ini.ReadInteger('Mode', 'Order', 100);
    AMeta.IsDefault := ParseBool(Ini.ReadString('Mode', 'Default', '0'), False);

    AMeta.Layout := Default(TViewLayout);
    AMeta.Layout.ModeId := AMeta.Id;
    ReadParts(Ini, AMeta.Layout);

    if (AMeta.Layout.Width <= 0) or (AMeta.Layout.Height <= 0) or (AMeta.Layout.BgFile = '') then
      raise Exception.CreateFmt(uAppStrings.S('err.layout_mode_incomplete'), [ALayoutIniPath]);

    FullBg := Trim(Ini.ReadString('ModeFull', 'Bg', ''));
    FullW := Ini.ReadInteger('ModeFull', 'Width', 0);
    FullH := Ini.ReadInteger('ModeFull', 'Height', 0);
    AMeta.HasFull := (FullBg <> '') and (FullW > 0) and (FullH > 0);
    if AMeta.HasFull then
    begin
      AMeta.FullLayout := AMeta.Layout;
      AMeta.FullLayout.ModeId := AMeta.Id;
      AMeta.FullLayout.Width := FullW;
      AMeta.FullLayout.Height := FullH;
      AMeta.FullLayout.BgFile := FullBg;
      if Ini.ValueExists('ModeFull', 'Transparent') then
        AMeta.FullLayout.Transparent :=
          ParseBool(Ini.ReadString('ModeFull', 'Transparent', ''), AMeta.Layout.Transparent);
      if Trim(Ini.ReadString('ModeFull', 'MaskColor', '')) <> '' then
        AMeta.FullLayout.MaskColor :=
          ParseColor(Ini.ReadString('ModeFull', 'MaskColor', ''), AMeta.Layout.MaskColor);
      if Trim(Ini.ReadString('ModeFull', 'Font', '')) <> '' then
        AMeta.FullLayout.FontFile := Trim(Ini.ReadString('ModeFull', 'Font', ''));
      AMeta.FullLayout.Graph := ReadGraph(Ini);
    end;

    Result := True;
  finally
    Ini.Free;
  end;
end;

end.
