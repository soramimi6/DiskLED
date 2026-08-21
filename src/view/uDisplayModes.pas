unit uDisplayModes;

{ Display modes are discovered from assets/<id>/layout.cfg.
  Adding a mode:
  1. Create assets/<id>/ with images
  2. Add layout.cfg (see existing modes)
  No Delphi unit registration is required. }

interface

uses
  uLayoutTypes;

const
  CModeOriginal = 'original';
  CModeCrystal = 'crystal';
  CModeMetalic = 'metalic';

type
  TDisplayModeDef = record
    Id: string;
    Caption: string;
    AssetDir: string;
    Order: Integer;
    HasFull: Boolean;
    Layout: TViewLayout;
    FullLayout: TViewLayout;
  end;

procedure LoadDisplayModes(const AAssetsRoot: string);
function DisplayModeCount: Integer;
function DisplayModeByIndex(AIndex: Integer): TDisplayModeDef;
function DisplayModeById(const AId: string): TDisplayModeDef;
function DefaultDisplayModeId: string;
function TryGetDisplayMode(const AId: string; out ADef: TDisplayModeDef): Boolean;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  uAppStrings,
  uSkinLoader;

var
  GModes: TArray<TDisplayModeDef>;
  GDefaultId: string;

procedure ClearModes;
begin
  SetLength(GModes, 0);
  GDefaultId := '';
end;

procedure SortModes;
var
  i, j: Integer;
  Tmp: TDisplayModeDef;
begin
  for i := 0 to High(GModes) - 1 do
    for j := i + 1 to High(GModes) do
      if (GModes[j].Order < GModes[i].Order) or
        ((GModes[j].Order = GModes[i].Order) and
         (CompareText(GModes[j].Caption, GModes[i].Caption) < 0)) then
      begin
        Tmp := GModes[i];
        GModes[i] := GModes[j];
        GModes[j] := Tmp;
      end;
end;

procedure LoadDisplayModes(const AAssetsRoot: string);
var
  Root: string;
  Dirs: TArray<string>;
  Dir: string;
  IniPath: string;
  Meta: TSkinModeMeta;
  Def: TDisplayModeDef;
  List: TList<TDisplayModeDef>;
  i: Integer;
begin
  ClearModes;
  Root := ExcludeTrailingPathDelimiter(AAssetsRoot);
  if not TDirectory.Exists(Root) then
    raise Exception.CreateFmt(S('err.assets_dir_missing'), [Root]);

  List := TList<TDisplayModeDef>.Create;
  try
    Dirs := TDirectory.GetDirectories(Root);
    for Dir in Dirs do
    begin
      IniPath := IncludeTrailingPathDelimiter(Dir) + 'layout.cfg';
      if not TFile.Exists(IniPath) then
        Continue;
      if not LoadSkinLayout(IniPath, Meta) then
        Continue;

      Def.Id := Meta.Id;
      Def.Caption := Meta.Caption;
      Def.AssetDir := ExtractFileName(ExcludeTrailingPathDelimiter(Dir));
      Def.Order := Meta.Order;
      Def.HasFull := Meta.HasFull;
      Def.Layout := Meta.Layout;
      Def.Layout.ModeId := Def.Id;
      Def.FullLayout := Meta.FullLayout;
      Def.FullLayout.ModeId := Def.Id;

      for i := 0 to List.Count - 1 do
        if SameText(List[i].Id, Def.Id) then
          raise Exception.CreateFmt(S('err.mode_id_duplicate'), [Def.Id]);

      List.Add(Def);
      if Meta.IsDefault and (GDefaultId = '') then
        GDefaultId := Def.Id;
    end;

    if List.Count = 0 then
      raise Exception.Create(S('err.no_display_modes'));

    SetLength(GModes, List.Count);
    for i := 0 to List.Count - 1 do
      GModes[i] := List[i];
    SortModes;
    if GDefaultId = '' then
      GDefaultId := GModes[0].Id;
  finally
    List.Free;
  end;
end;

function DisplayModeCount: Integer;
begin
  Result := Length(GModes);
end;

function DisplayModeByIndex(AIndex: Integer): TDisplayModeDef;
begin
  if (AIndex < 0) or (AIndex >= Length(GModes)) then
    raise Exception.Create(S('err.mode_index_out_of_range'));
  Result := GModes[AIndex];
end;

function TryGetDisplayMode(const AId: string; out ADef: TDisplayModeDef): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(GModes) do
    if SameText(GModes[i].Id, AId) then
    begin
      ADef := GModes[i];
      Exit(True);
    end;
  Result := False;
end;

function DisplayModeById(const AId: string): TDisplayModeDef;
begin
  if not TryGetDisplayMode(AId, Result) then
    raise Exception.CreateFmt(S('err.unknown_mode'), [AId]);
end;

function DefaultDisplayModeId: string;
var
  Def: TDisplayModeDef;
begin
  if Length(GModes) = 0 then
    raise Exception.Create(S('err.no_modes_registered'));
  if (GDefaultId <> '') and TryGetDisplayMode(GDefaultId, Def) then
    Result := Def.Id
  else if TryGetDisplayMode(CModeOriginal, Def) then
    Result := Def.Id
  else
    Result := GModes[0].Id;
end;

end.
