unit uSkinLoader;

{ Loads assets/<id>/layout.cfg into compact + optional full TViewLayout.
  Compact and full hold no shared state: every setting lives in a section
  named for its own view (Compact/Full suffix) with no inheritance between
  them -- see assets/LAYOUT.md. }

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

{ Meter-kind parts (Cpu/Mem/Swap/*Meter/Audio*) additionally require their
  own Kind=/Strength= -- there is no shared [Ballistic] default any more, so
  a defined meter part (File<>'') must state its own ballistic behavior.
  A part that isn't defined at all (File='') needs neither. }
function ReadMeterSprite(Ini: TCustomIniFile; const ASection: string): TSpriteStrip;
var
  KindRaw, StrengthRaw: string;
  Kind: TBallisticKind;
begin
  Result := ReadSprite(Ini, ASection);
  if Result.FileName = '' then
    Exit;

  KindRaw := Trim(Ini.ReadString(ASection, 'Kind', ''));
  StrengthRaw := Trim(Ini.ReadString(ASection, 'Strength', ''));
  if (KindRaw = '') or (StrengthRaw = '') then
    raise Exception.CreateFmt(uAppStrings.S('err.layout_ballistic_required'),
      [GCurrentPath, ASection]);

  if not TryParseBallisticKind(KindRaw, Kind) then
    raise ErrValue(ASection, 'Kind', KindRaw);
  Result.BallisticKind := Kind;
  Result.BallisticStrength := ReadStrictInt(Ini, ASection, 'Strength', 0);
  if (Result.BallisticStrength < 0) or (Result.BallisticStrength > 100) then
    raise ErrValue(ASection, 'Strength', StrengthRaw);
end;

function ReadDigitValue(Ini: TCustomIniFile; const ASection: string): TDigitValue;
var
  FontMaskRaw: string;
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

  { ValStyle=system. }
  Result.FontName := Trim(Ini.ReadString(ASection, 'ValFont', ''));
  Result.FontSize := ReadStrictInt(Ini, ASection, 'ValFontSize', 9);
  if Result.FontSize < 1 then
    raise ErrValue(ASection, 'ValFontSize', IntToStr(Result.FontSize));
  Result.Color := ReadStrictColor(Ini, ASection, 'ValColor', clBlack);
  Result.Bold := ReadStrictBool(Ini, ASection, 'ValBold', False);

  { ValStyle=bitmap: this part's own font sheet, instead of a shared
    mode-wide [Mode] Font=. Required when the readout is actually enabled --
    same "active part must state its own dependency" rule as ReadMeterSprite's
    Kind/Strength. }
  Result.BitmapFile := Trim(Ini.ReadString(ASection, 'ValFontFile', ''));
  if Result.Enabled and (Result.Style = dsBitmap) and (Result.BitmapFile = '') then
    raise Exception.CreateFmt(uAppStrings.S('err.layout_digit_font_required'),
      [GCurrentPath, ASection]);
  FontMaskRaw := Trim(Ini.ReadString(ASection, 'ValFontMaskColor', ''));
  Result.FontTransparent := FontMaskRaw <> '';
  if Result.FontTransparent then
    Result.FontMaskColor := ReadStrictColor(Ini, ASection, 'ValFontMaskColor', clBlack)
  else
    Result.FontMaskColor := clBlack;
end;

{ Reads every part section (19 sprites + Cpu/Mem/Swap digit readouts), each
  named '<Part>' + ASuffix -- ASuffix is 'Compact' or 'Full'. Compact and
  full are read independently with no fallback between them: a part not
  defined under a given suffix simply doesn't exist in that view, exactly
  like an omitted section always meant "unused". A skin that wants the same
  part in both views restates its section under both suffixes. }
procedure ReadPartSections(Ini: TCustomIniFile; const ASuffix: string; var ALayout: TViewLayout);
begin
  ALayout.Cpu := ReadMeterSprite(Ini, 'Cpu' + ASuffix);
  ALayout.Mem := ReadMeterSprite(Ini, 'Mem' + ASuffix);
  ALayout.Swap := ReadMeterSprite(Ini, 'Swap' + ASuffix);
  ALayout.DiskReadMeter := ReadMeterSprite(Ini, 'DiskReadMeter' + ASuffix);
  ALayout.DiskWriteMeter := ReadMeterSprite(Ini, 'DiskWriteMeter' + ASuffix);
  ALayout.DiskIoMeter := ReadMeterSprite(Ini, 'DiskIoMeter' + ASuffix);
  ALayout.NetInMeter := ReadMeterSprite(Ini, 'NetInMeter' + ASuffix);
  ALayout.NetOutMeter := ReadMeterSprite(Ini, 'NetOutMeter' + ASuffix);
  ALayout.NetIoMeter := ReadMeterSprite(Ini, 'NetIoMeter' + ASuffix);
  ALayout.Audio := ReadMeterSprite(Ini, 'Audio' + ASuffix);
  ALayout.AudioL := ReadMeterSprite(Ini, 'AudioL' + ASuffix);
  ALayout.AudioR := ReadMeterSprite(Ini, 'AudioR' + ASuffix);

  ALayout.Ping := ReadSprite(Ini, 'Ping' + ASuffix);
  ALayout.DiskRead := ReadSprite(Ini, 'DiskRead' + ASuffix);
  ALayout.DiskWrite := ReadSprite(Ini, 'DiskWrite' + ASuffix);
  ALayout.DiskRW := ReadSprite(Ini, 'DiskRW' + ASuffix);
  ALayout.NetIn := ReadSprite(Ini, 'NetIn' + ASuffix);
  ALayout.NetOut := ReadSprite(Ini, 'NetOut' + ASuffix);
  ALayout.NetActivity := ReadSprite(Ini, 'NetActivity' + ASuffix);
  ALayout.NetTotal := ReadSprite(Ini, 'NetTotal' + ASuffix);

  ALayout.CpuVal := ReadDigitValue(Ini, 'Cpu' + ASuffix);
  ALayout.MemVal := ReadDigitValue(Ini, 'Mem' + ASuffix);
  ALayout.SwapVal := ReadDigitValue(Ini, 'Swap' + ASuffix);
end;

function ReadGraphLane(Ini: TCustomIniFile; const AKey, AColorKey: string;
  ADefaultColor: TColor): TGraphLane;
var
  Raw: string;
  Parts: TArray<string>;
  X, Y, W, H: Integer;
begin
  Result := Default(TGraphLane);
  Raw := Trim(Ini.ReadString('GraphFull', AKey, ''));
  if Raw = '' then
    Exit;
  Parts := Raw.Split([',']);
  if (Length(Parts) <> 4) or
    (not TryStrToInt(Trim(Parts[0]), X)) or (not TryStrToInt(Trim(Parts[1]), Y)) or
    (not TryStrToInt(Trim(Parts[2]), W)) or (not TryStrToInt(Trim(Parts[3]), H)) or
    (W <= 0) or (H <= 0) then
    raise ErrValue('GraphFull', AKey, Raw);
  Result.X := X;
  Result.Y := Y;
  Result.W := W;
  Result.H := H;
  Result.Color := ReadStrictColor(Ini, 'GraphFull', AColorKey, ADefaultColor);
  Result.Enabled := True;
end;

function ReadGraph(Ini: TCustomIniFile): TGraphLayout;
var
  StyleRaw: string;
begin
  Result := Default(TGraphLayout);
  StyleRaw := LowerCase(Trim(Ini.ReadString('GraphFull', 'Style', '')));
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

  GCurrentPath := ALayoutIniPath;
  Ini := TMemIniFile.Create(ALayoutIniPath);
  try
    { [General]: identity, independent of compact/full. }
    FolderName := ExtractFileName(ExcludeTrailingPathDelimiter(ExtractFilePath(ALayoutIniPath)));
    AMeta.Id := Trim(Ini.ReadString('General', 'Id', FolderName));
    if AMeta.Id = '' then
      AMeta.Id := FolderName;
    AMeta.Caption := Trim(Ini.ReadString('General', 'Caption', AMeta.Id));
    AMeta.Order := ReadStrictInt(Ini, 'General', 'Order', 100);
    AMeta.IsDefault := ReadStrictBool(Ini, 'General', 'Default', False);

    { [GeneralCompact]: compact window definition -- required. }
    AMeta.Layout := Default(TViewLayout);
    AMeta.Layout.ModeId := AMeta.Id;
    AMeta.Layout.Transparent := ReadStrictBool(Ini, 'GeneralCompact', 'Transparent', True);
    AMeta.Layout.MaskColor := ReadStrictColor(Ini, 'GeneralCompact', 'MaskColor', clBlack);
    AMeta.Layout.BgFile := Trim(Ini.ReadString('GeneralCompact', 'Bg', ''));
    AMeta.Layout.Width := Ini.ReadInteger('GeneralCompact', 'Width', 0);
    AMeta.Layout.Height := Ini.ReadInteger('GeneralCompact', 'Height', 0);
    if (AMeta.Layout.Width <= 0) or (AMeta.Layout.Height <= 0) or (AMeta.Layout.BgFile = '') then
      raise Exception.CreateFmt(uAppStrings.S('err.layout_mode_incomplete'), [ALayoutIniPath]);
    ReadPartSections(Ini, 'Compact', AMeta.Layout);

    { [GeneralFull]: optional. Present (Width/Height/Bg all set) = full view
      enabled; each part below is read from its own '<Part>Full' section
      with no fallback to compact. }
    FullBg := Trim(Ini.ReadString('GeneralFull', 'Bg', ''));
    FullW := Ini.ReadInteger('GeneralFull', 'Width', 0);
    FullH := Ini.ReadInteger('GeneralFull', 'Height', 0);
    AMeta.HasFull := (FullBg <> '') and (FullW > 0) and (FullH > 0);
    if AMeta.HasFull then
    begin
      AMeta.FullLayout := Default(TViewLayout);
      AMeta.FullLayout.ModeId := AMeta.Id;
      AMeta.FullLayout.Width := FullW;
      AMeta.FullLayout.Height := FullH;
      AMeta.FullLayout.BgFile := FullBg;
      AMeta.FullLayout.Transparent := ReadStrictBool(Ini, 'GeneralFull', 'Transparent', True);
      AMeta.FullLayout.MaskColor := ReadStrictColor(Ini, 'GeneralFull', 'MaskColor', clBlack);
      AMeta.FullLayout.Graph := ReadGraph(Ini);
      ReadPartSections(Ini, 'Full', AMeta.FullLayout);
    end;

    Result := True;
  finally
    Ini.Free;
  end;
end;

end.
