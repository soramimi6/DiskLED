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
    TrayOffFile: string;
    TrayOnFile: string;
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

var
  { Path of the layout.cfg currently being parsed, for the strict Read*
    validators' error text below. Set once per LoadSkinLayout call; this
    loader runs synchronously and is never reentrant, so a module var is
    simpler than threading the path through every helper's parameter list. }
  GCurrentPath: string;

function ErrValue(const ASection, AKey, ARaw: string): Exception;
begin
  Result := Exception.CreateFmt(uAppStrings.S('err.layout_value_invalid'),
    [GCurrentPath, ASection, AKey, ARaw]);
end;

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

function TryParseColor(const S: string; out AColor: TColor): Boolean;
var
  V: string;
  R, G, B: Integer;
begin
  V := Trim(S);
  if (Length(V) = 7) and (V[1] = '#') and
    IsHexChar(V[2]) and IsHexChar(V[3]) and IsHexChar(V[4]) and
    IsHexChar(V[5]) and IsHexChar(V[6]) and IsHexChar(V[7]) then
  begin
    R := StrToInt('$' + Copy(V, 2, 2));
    G := StrToInt('$' + Copy(V, 4, 2));
    B := StrToInt('$' + Copy(V, 6, 2));
    AColor := RGB(R, G, B);
    Exit(True);
  end;
  if (Length(V) >= 2) and (LowerCase(Copy(V, 1, 2)) = 'cl') then
  try
    AColor := StringToColor(V);
    Exit(True);
  except
    Exit(False);
  end;
  Result := False;
end;

function ParseColor(const S: string; ADefault: TColor): TColor;
begin
  if (Trim(S) = '') or not TryParseColor(S, Result) then
    Result := ADefault;
end;

{ Strict Read* helpers: a missing key or a key whose value trims to empty is
  "unused", same as the legacy Parse* helpers above -- returns ADefault. A key
  that IS present with a non-empty value that fails to parse raises, instead
  of silently falling back (this is what item 3/B in docs/PLANNED-3.1.2.md
  hardens: previously only the required Mode fields were checked this way). }

function ReadStrictInt(Ini: TCustomIniFile; const ASection, AKey: string; ADefault: Integer): Integer;
var
  Raw: string;
begin
  Raw := Trim(Ini.ReadString(ASection, AKey, ''));
  if Raw = '' then
    Exit(ADefault);
  if not TryStrToInt(Raw, Result) then
    raise ErrValue(ASection, AKey, Raw);
end;

function ReadStrictBool(Ini: TCustomIniFile; const ASection, AKey: string; ADefault: Boolean): Boolean;
var
  Raw, V: string;
begin
  Raw := Trim(Ini.ReadString(ASection, AKey, ''));
  if Raw = '' then
    Exit(ADefault);
  V := LowerCase(Raw);
  if (V = '1') or (V = 'true') or (V = 'yes') or (V = 'on') then
    Exit(True);
  if (V = '0') or (V = 'false') or (V = 'no') or (V = 'off') then
    Exit(False);
  raise ErrValue(ASection, AKey, Raw);
end;

function ReadStrictColor(Ini: TCustomIniFile; const ASection, AKey: string; ADefault: TColor): TColor;
var
  Raw: string;
begin
  Raw := Trim(Ini.ReadString(ASection, AKey, ''));
  if Raw = '' then
    Exit(ADefault);
  if not TryParseColor(Raw, Result) then
    raise ErrValue(ASection, AKey, Raw);
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

function TryParseBallisticKind(const S: string; out AKind: TBallisticKind): Boolean;
var
  V: string;
begin
  V := LowerCase(Trim(S));
  Result := True;
  if V = 'bar' then
    AKind := bkBar
  else if V = 'peak' then
    AKind := bkPeak
  else if V = 'vu' then
    AKind := bkVu
  else
    Result := False;
end;

function ParseBallisticParamsStrict(const ASection, AKey, Raw: string;
  const AFallback: TBallisticParams): TBallisticParams;
var
  V: string;
  KindStr: string;
  StrStr: string;
  P: Integer;
  Kind: TBallisticKind;
  Strength: Integer;
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
  begin
    if not TryParseBallisticKind(KindStr, Kind) then
      raise ErrValue(ASection, AKey, Raw);
    Result.Kind := Kind;
  end;
  if StrStr <> '' then
  begin
    if (not TryStrToInt(StrStr, Strength)) or (Strength < 0) or (Strength > 100) then
      raise ErrValue(ASection, AKey, Raw);
    Result.Strength := Strength;
  end;
end;

function ReadBallisticChannel(Ini: TCustomIniFile; const AKey: string;
  const AFallback: TBallisticParams): TBallisticParams;
begin
  if not Ini.ValueExists('Ballistic', AKey) then
    Exit(AFallback);
  Result := ParseBallisticParamsStrict('Ballistic', AKey, Ini.ReadString('Ballistic', AKey, ''), AFallback);
end;

procedure ReadBallistics(Ini: TCustomIniFile; var ALayout: TViewLayout);
var
  Def, AudioDef: TBallisticParams;
  DefaultRaw: string;
  Kind: TBallisticKind;
begin
  Def := DefaultBallisticParams;
  DefaultRaw := Trim(Ini.ReadString('Ballistic', 'Default', ''));
  if DefaultRaw <> '' then
  begin
    if not TryParseBallisticKind(DefaultRaw, Kind) then
      raise ErrValue('Ballistic', 'Default', DefaultRaw);
    Def.Kind := Kind;
  end;
  Def.Strength := ReadStrictInt(Ini, 'Ballistic', 'Strength', Def.Strength);
  if (Def.Strength < 0) or (Def.Strength > 100) then
    raise ErrValue('Ballistic', 'Strength', IntToStr(Def.Strength));

  ALayout.Ballistics.Cpu := ReadBallisticChannel(Ini, 'Cpu', Def);
  ALayout.Ballistics.Mem := ReadBallisticChannel(Ini, 'Mem', Def);
  ALayout.Ballistics.Swap := ReadBallisticChannel(Ini, 'Swap', Def);
  ALayout.Ballistics.DiskRead := ReadBallisticChannel(Ini, 'DiskReadMeter', Def);
  ALayout.Ballistics.DiskWrite := ReadBallisticChannel(Ini, 'DiskWriteMeter', Def);
  ALayout.Ballistics.NetIn := ReadBallisticChannel(Ini, 'NetInMeter', Def);
  ALayout.Ballistics.NetOut := ReadBallisticChannel(Ini, 'NetOutMeter', Def);
  AudioDef := DefaultBallisticParams;
  AudioDef.Kind := bkPeak;
  ALayout.Ballistics.Audio := ReadBallisticChannel(Ini, 'Audio', AudioDef);
  ALayout.Ballistics.AudioL := ReadBallisticChannel(Ini, 'AudioL',
    ALayout.Ballistics.Audio);
  ALayout.Ballistics.AudioR := ReadBallisticChannel(Ini, 'AudioR',
    ALayout.Ballistics.Audio);
end;

function ReadSprite(Ini: TCustomIniFile; const ASection: string): TSpriteStrip;
var
  FileName: string;
  HasMask: Boolean;
begin
  Result := Default(TSpriteStrip);
  FileName := Trim(Ini.ReadString(ASection, 'File', ''));
  if FileName = '' then
    Exit;

  Result.FileName := FileName;
  Result.X := ReadStrictInt(Ini, ASection, 'X', 0);
  Result.Y := ReadStrictInt(Ini, ASection, 'Y', 0);
  Result.Frames := ReadStrictInt(Ini, ASection, 'Frames', 1);
  if Result.Frames < 1 then
    raise ErrValue(ASection, 'Frames', IntToStr(Result.Frames));

  HasMask := Trim(Ini.ReadString(ASection, 'MaskColor', '')) <> '';
  Result.Transparent := ReadStrictBool(Ini, ASection, 'Transparent', HasMask);

  if Result.Transparent then
    Result.MaskColor := ReadStrictColor(Ini, ASection, 'MaskColor', clBlack)
  else if HasMask then
    ReadStrictColor(Ini, ASection, 'MaskColor', clBlack); // validate even though unused
end;

function ReadDigitValue(Ini: TCustomIniFile; const ASection: string): TDigitValue;
begin
  Result := Default(TDigitValue);
  Result.Enabled := ReadStrictBool(Ini, ASection, 'ValSW', False);
  Result.Style := ParseDigitStyle(Ini.ReadString(ASection, 'ValStyle', 'bitmap'));
  Result.X := ReadStrictInt(Ini, ASection, 'ValX', 0);
  Result.Y := ReadStrictInt(Ini, ASection, 'ValY', 0);
  Result.Digits := ReadStrictInt(Ini, ASection, 'ValB', 3);
  if Result.Digits < 1 then
    raise ErrValue(ASection, 'ValB', IntToStr(Result.Digits));
  Result.FillZero := ReadStrictBool(Ini, ASection, 'ValFZ', False);
  Result.FontName := Trim(Ini.ReadString(ASection, 'ValFont', ''));
  Result.FontSize := ReadStrictInt(Ini, ASection, 'ValFontSize', 9);
  if Result.FontSize < 1 then
    raise ErrValue(ASection, 'ValFontSize', IntToStr(Result.FontSize));
  Result.Color := ReadStrictColor(Ini, ASection, 'ValColor', clBlack);
  Result.Bold := ReadStrictBool(Ini, ASection, 'ValBold', False);
end;

procedure ReadParts(Ini: TCustomIniFile; var ALayout: TViewLayout);
var
  FontMaskRaw: string;
begin
  ALayout.Transparent := ReadStrictBool(Ini, 'Mode', 'Transparent', True);
  ALayout.MaskColor := ReadStrictColor(Ini, 'Mode', 'MaskColor', clBlack);
  ALayout.BgFile := Trim(Ini.ReadString('Mode', 'Bg', ''));
  ALayout.Width := Ini.ReadInteger('Mode', 'Width', 0);
  ALayout.Height := Ini.ReadInteger('Mode', 'Height', 0);
  ALayout.FontFile := Trim(Ini.ReadString('Mode', 'Font', ''));
  FontMaskRaw := Trim(Ini.ReadString('Mode', 'FontMaskColor', ''));
  ALayout.FontTransparent := FontMaskRaw <> '';
  if ALayout.FontTransparent then
    ALayout.FontMaskColor := ReadStrictColor(Ini, 'Mode', 'FontMaskColor', clBlack)
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
  ALayout.Audio := ReadSprite(Ini, 'Audio');
  ALayout.AudioL := ReadSprite(Ini, 'AudioL');
  ALayout.AudioR := ReadSprite(Ini, 'AudioR');
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
  Parts: TArray<string>;
  X, Y, W, H: Integer;
begin
  Result := Default(TGraphLane);
  Raw := Trim(Ini.ReadString('Graph', AKey, ''));
  if Raw = '' then
    Exit;
  Parts := Raw.Split([',']);
  if (Length(Parts) <> 4) or
    (not TryStrToInt(Trim(Parts[0]), X)) or (not TryStrToInt(Trim(Parts[1]), Y)) or
    (not TryStrToInt(Trim(Parts[2]), W)) or (not TryStrToInt(Trim(Parts[3]), H)) or
    (W <= 0) or (H <= 0) then
    raise ErrValue('Graph', AKey, Raw);
  Result.X := X;
  Result.Y := Y;
  Result.W := W;
  Result.H := H;
  Result.Color := ReadStrictColor(Ini, 'Graph', AColorKey, ADefaultColor);
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

procedure ReadTray(Ini: TCustomIniFile; var AMeta: TSkinModeMeta);
begin
  { [Tray] is optional: a missing section leaves both file names empty, and
    the caller falls back to the fixed app icon rather than failing. }
  AMeta.TrayOffFile := Trim(Ini.ReadString('Tray', 'Off', ''));
  AMeta.TrayOnFile := Trim(Ini.ReadString('Tray', 'On', ''));
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

  GCurrentPath := ALayoutIniPath;
  Ini := TMemIniFile.Create(ALayoutIniPath);
  try
    FolderName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(ALayoutIniPath)));
    AMeta.Id := Trim(Ini.ReadString('Mode', 'Id', FolderName));
    if AMeta.Id = '' then
      AMeta.Id := FolderName;
    AMeta.Caption := Trim(Ini.ReadString('Mode', 'Caption', AMeta.Id));
    AMeta.Order := ReadStrictInt(Ini, 'Mode', 'Order', 100);
    AMeta.IsDefault := ReadStrictBool(Ini, 'Mode', 'Default', False);

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
      AMeta.FullLayout.Transparent :=
        ReadStrictBool(Ini, 'ModeFull', 'Transparent', AMeta.Layout.Transparent);
      AMeta.FullLayout.MaskColor :=
        ReadStrictColor(Ini, 'ModeFull', 'MaskColor', AMeta.Layout.MaskColor);
      if Trim(Ini.ReadString('ModeFull', 'Font', '')) <> '' then
        AMeta.FullLayout.FontFile := Trim(Ini.ReadString('ModeFull', 'Font', ''));
      AMeta.FullLayout.Graph := ReadGraph(Ini);
    end;

    ReadTray(Ini, AMeta);

    Result := True;
  finally
    Ini.Free;
  end;
end;

end.
