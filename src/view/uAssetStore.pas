unit uAssetStore;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics,
  uLayoutTypes;

type
  TAssetStore = class
  private
    FRoot: string;
    FGraphics: TObjectDictionary<string, TBitmap>;
    class function LoadGraphic(const APath: string): TBitmap; static;
    function CacheKey(const AModeId, AFileName: string): string;
  public
    constructor Create(const ARoot: string);
    destructor Destroy; override;
    function Background(const ALayout: TViewLayout): TBitmap;
    function Graphic(const ALayout: TViewLayout; const AFileName: string): TBitmap;
    class function LocateRoot: string; static;
    property Root: string read FRoot;
  end;

implementation

uses
  System.IOUtils,
  Vcl.Imaging.pngimage,
  uAppStrings,
  uDisplayModes;

class function TAssetStore.LoadGraphic(const APath: string): TBitmap;
var
  Png: TPngImage;
  Ext: string;
  Temp: TBitmap;
begin
  if not TFile.Exists(APath) then
    raise EFileNotFoundException.CreateFmt(S('err.image_not_found'), [APath]);

  Result := TBitmap.Create;
  Temp := TBitmap.Create;
  try
    try
      Ext := LowerCase(ExtractFileExt(APath));
      if Ext = '.png' then
      begin
        Png := TPngImage.Create;
        try
          Png.LoadFromFile(APath);
          Temp.Assign(Png);
        finally
          Png.Free;
        end;
      end
      else
        Temp.LoadFromFile(APath);

      Result.PixelFormat := pf24bit;
      Result.SetSize(Temp.Width, Temp.Height);
      Result.Canvas.Draw(0, 0, Temp);
    except
      Result.Free;
      raise;
    end;
  finally
    Temp.Free;
  end;
end;

constructor TAssetStore.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := ExcludeTrailingPathDelimiter(ARoot);
  FGraphics := TObjectDictionary<string, TBitmap>.Create([doOwnsValues]);
end;

destructor TAssetStore.Destroy;
begin
  FGraphics.Free;
  inherited;
end;

function TAssetStore.CacheKey(const AModeId, AFileName: string): string;
begin
  Result := LowerCase(AModeId + '|' + AFileName);
end;

function TAssetStore.Graphic(const ALayout: TViewLayout; const AFileName: string): TBitmap;
var
  Def: TDisplayModeDef;
  Path: string;
  Key: string;
begin
  if AFileName = '' then
    raise EArgumentException.Create(S('err.image_name_empty'));

  Key := CacheKey(ALayout.ModeId, AFileName);
  if FGraphics.TryGetValue(Key, Result) then
    Exit;

  Def := DisplayModeById(ALayout.ModeId);
  Path := FRoot + '\' + Def.AssetDir + '\' + AFileName;
  Result := LoadGraphic(Path);
  FGraphics.Add(Key, Result);
end;

function TAssetStore.Background(const ALayout: TViewLayout): TBitmap;
begin
  Result := Graphic(ALayout, ALayout.BgFile);
end;

class function TAssetStore.LocateRoot: string;
var
  Dir: string;
  Parent: string;
  SubDirs: TArray<string>;
  Sub: string;
  Found: Boolean;
begin
  Dir := ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  while Dir <> '' do
  begin
    Result := Dir + '\assets';
    if TDirectory.Exists(Result) then
    begin
      Found := False;
      SubDirs := TDirectory.GetDirectories(Result);
      for Sub in SubDirs do
        if TFile.Exists(IncludeTrailingPathDelimiter(Sub) + 'layout.cfg') then
        begin
          Found := True;
          Break;
        end;
      if Found then
        Exit;
    end;
    Parent := ExcludeTrailingPathDelimiter(ExtractFilePath(Dir));
    if (Parent = '') or (Parent = Dir) then
      Break;
    Dir := Parent;
  end;
  raise EDirectoryNotFoundException.Create(S('err.assets_not_found'));
end;

end.
