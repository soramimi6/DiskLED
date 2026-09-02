unit uSettings;

{ DiskLED.ini: prefer exe directory; fall back to %AppData%\DiskLED when needed. }

interface

uses
  uMetricsTypes;

type
  TAppSettings = class
  private
    FFilePath: string;
    FMode: string;
    FStayOnTop: Boolean;
    FFps: Integer;
    FWindowX: Integer;
    FWindowY: Integer;
    FStartup: Boolean;
    FCompact: Boolean;
    FGraphRateHz: Double;
    FSpeedScale: TSpeedScale;
    FPingEnabled: Boolean;
    FPingIntervalSec: Integer;
    FPingAutoGateway: Boolean;
    FPingHost: string;
    FPingFairMs: Integer;
    FPingSlowMs: Integer;
    FPingTimeoutMs: Integer;
    FDashboardOpen: Boolean;
    FDashboardX: Integer;
    FDashboardY: Integer;
    FDashboardW: Integer;
    FDashboardH: Integer;
    FDashboardMaximized: Boolean;
    FUpdateEnabled: Boolean;
    FUpdateLastNotified: string;
    FUpdateLatestKnown: string;
    class function ExeIniPath: string; static;
    class function AppDataIniPath: string; static;
    class function CanWriteDir(const ADir: string): Boolean; static;
    procedure ResolvePath;
    procedure ApplyDefaults;
    procedure Normalize;
  public
    constructor Create;
    procedure Load;
    procedure Save;
    property FilePath: string read FFilePath;
    property Mode: string read FMode write FMode;
    property StayOnTop: Boolean read FStayOnTop write FStayOnTop;
    property Fps: Integer read FFps write FFps;
    property WindowX: Integer read FWindowX write FWindowX;
    property WindowY: Integer read FWindowY write FWindowY;
    property Startup: Boolean read FStartup write FStartup;
    property Compact: Boolean read FCompact write FCompact;
    property GraphRateHz: Double read FGraphRateHz write FGraphRateHz;
    property SpeedScale: TSpeedScale read FSpeedScale write FSpeedScale;
    property PingEnabled: Boolean read FPingEnabled write FPingEnabled;
    property PingIntervalSec: Integer read FPingIntervalSec write FPingIntervalSec;
    property PingAutoGateway: Boolean read FPingAutoGateway write FPingAutoGateway;
    property PingHost: string read FPingHost write FPingHost;
    property PingFairMs: Integer read FPingFairMs write FPingFairMs;
    property PingSlowMs: Integer read FPingSlowMs write FPingSlowMs;
    property PingTimeoutMs: Integer read FPingTimeoutMs write FPingTimeoutMs;
    property DashboardOpen: Boolean read FDashboardOpen write FDashboardOpen;
    property DashboardX: Integer read FDashboardX write FDashboardX;
    property DashboardY: Integer read FDashboardY write FDashboardY;
    property DashboardW: Integer read FDashboardW write FDashboardW;
    property DashboardH: Integer read FDashboardH write FDashboardH;
    { Restored bounds are 96dpi DIP. Maximized is stored separately so a
      maximized frame is not written as WindowW/WindowH. }
    property DashboardMaximized: Boolean read FDashboardMaximized write FDashboardMaximized;
    { GitHub Latest check at startup. LastNotified is balloon-once; LatestKnown keeps the menu. }
    property UpdateEnabled: Boolean read FUpdateEnabled write FUpdateEnabled;
    property UpdateLastNotified: string read FUpdateLastNotified write FUpdateLastNotified;
    property UpdateLatestKnown: string read FUpdateLatestKnown write FUpdateLatestKnown;
  end;

implementation

uses
  System.SysUtils,
  System.IniFiles;

const
  CIniName = 'DiskLED.ini';

class function TAppSettings.ExeIniPath: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + CIniName;
end;

class function TAppSettings.AppDataIniPath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
    'DiskLED' + PathDelim + CIniName;
end;

class function TAppSettings.CanWriteDir(const ADir: string): Boolean;
var
  Probe: string;
  H: TextFile;
begin
  Result := False;
  if ADir = '' then
    Exit;
  try
    if not DirectoryExists(ADir) then
      ForceDirectories(ADir);
    Probe := IncludeTrailingPathDelimiter(ADir) + '~diskled_write_probe.tmp';
    AssignFile(H, Probe);
    Rewrite(H);
    Write(H, 'ok');
    CloseFile(H);
    DeleteFile(Probe);
    Result := True;
  except
    Result := False;
    try
      if FileExists(Probe) then
        DeleteFile(Probe);
    except
    end;
  end;
end;

constructor TAppSettings.Create;
begin
  inherited Create;
  ApplyDefaults;
  ResolvePath;
end;

procedure TAppSettings.ApplyDefaults;
begin
  FMode := 'original';
  FStayOnTop := True;
  FFps := 15;
  FWindowX := 100;
  FWindowY := 100;
  FStartup := False;
  FCompact := True;
  FGraphRateHz := 1.0;
  FSpeedScale := ssLinear;
  FPingEnabled := True;
  FPingIntervalSec := 300;
  FPingAutoGateway := False;
  FPingHost := 'mg6.jp';
  FPingFairMs := 200;
  FPingSlowMs := 500;
  FPingTimeoutMs := 1000;
  FDashboardOpen := False;
  FDashboardX := 100;
  FDashboardY := 100;
  FDashboardW := 960;
  FDashboardH := 720;
  FDashboardMaximized := False;
  FUpdateEnabled := True;
  FUpdateLastNotified := '';
  FUpdateLatestKnown := '';
end;

procedure TAppSettings.ResolvePath;
var
  ExePath, AppPath, ExeDir: string;
begin
  ExePath := ExeIniPath;
  AppPath := AppDataIniPath;
  if FileExists(ExePath) then
    FFilePath := ExePath
  else if FileExists(AppPath) then
    FFilePath := AppPath
  else
  begin
    ExeDir := ExtractFilePath(ExePath);
    if CanWriteDir(ExeDir) then
      FFilePath := ExePath
    else
    begin
      ForceDirectories(ExtractFilePath(AppPath));
      FFilePath := AppPath;
    end;
  end;
end;

procedure TAppSettings.Normalize;
begin
  if not ((FFps = 10) or (FFps = 15) or (FFps = 20)) then
    FFps := 15;
  if Abs(FGraphRateHz - 2.0) < 0.01 then
    FGraphRateHz := 2.0
  else if Abs(FGraphRateHz - 0.5) < 0.01 then
    FGraphRateHz := 0.5
  else
    FGraphRateHz := 1.0;
  if FSpeedScale <> ssLog then
    FSpeedScale := ssLinear;
  if FPingIntervalSec < 300 then
    FPingIntervalSec := 300;
  if Trim(FPingHost) = '' then
    FPingHost := 'mg6.jp';
  if FPingFairMs < 1 then
    FPingFairMs := 200;
  if FPingSlowMs <= FPingFairMs then
    FPingSlowMs := FPingFairMs + 1;
  if FPingTimeoutMs <= FPingSlowMs then
    FPingTimeoutMs := FPingSlowMs + 1;
  if Trim(FMode) = '' then
    FMode := 'original';
  { Dashboard size/pos are 96dpi DIP. Clamp leftover physical pixels from
    earlier PMv2 builds that stored window pixels instead of DIP. }
  if FDashboardW > 3840 then
    FDashboardW := 960;
  if FDashboardH > 2400 then
    FDashboardH := 720;
  if FDashboardW < 800 then
    FDashboardW := 800;
  if FDashboardH < 600 then
    FDashboardH := 600;
end;

procedure TAppSettings.Load;
var
  Ini: TMemIniFile;
begin
  ApplyDefaults;
  ResolvePath;
  if not FileExists(FFilePath) then
  begin
    Normalize;
    Exit;
  end;

  Ini := TMemIniFile.Create(FFilePath);
  try
    FMode := Ini.ReadString('General', 'Mode', FMode);
    FStayOnTop := Ini.ReadBool('General', 'StayOnTop', FStayOnTop);
    FFps := Ini.ReadInteger('General', 'Fps', FFps);
    FWindowX := Ini.ReadInteger('General', 'WindowX', FWindowX);
    FWindowY := Ini.ReadInteger('General', 'WindowY', FWindowY);
    FStartup := Ini.ReadBool('General', 'Startup', FStartup);
    FCompact := Ini.ReadBool('View', 'Compact', FCompact);
    FGraphRateHz := Ini.ReadFloat('View', 'GraphRateHz', FGraphRateHz);
    if SameText(Trim(Ini.ReadString('View', 'SpeedScale', 'linear')), 'log') then
      FSpeedScale := ssLog
    else
      FSpeedScale := ssLinear;
    FPingEnabled := Ini.ReadBool('Ping', 'Enabled', FPingEnabled);
    FPingIntervalSec := Ini.ReadInteger('Ping', 'IntervalSec', FPingIntervalSec);
    FPingAutoGateway := Ini.ReadBool('Ping', 'AutoGateway', FPingAutoGateway);
    FPingHost := Ini.ReadString('Ping', 'Host', FPingHost);
    FPingFairMs := Ini.ReadInteger('Ping', 'ThresholdFairMs', FPingFairMs);
    FPingSlowMs := Ini.ReadInteger('Ping', 'ThresholdSlowMs', FPingSlowMs);
    FPingTimeoutMs := Ini.ReadInteger('Ping', 'ThresholdTimeoutMs', FPingTimeoutMs);
    FDashboardOpen := Ini.ReadBool('Dashboard', 'Open', FDashboardOpen);
    FDashboardX := Ini.ReadInteger('Dashboard', 'WindowX', FDashboardX);
    FDashboardY := Ini.ReadInteger('Dashboard', 'WindowY', FDashboardY);
    FDashboardW := Ini.ReadInteger('Dashboard', 'WindowW', FDashboardW);
    FDashboardH := Ini.ReadInteger('Dashboard', 'WindowH', FDashboardH);
    FDashboardMaximized := Ini.ReadBool('Dashboard', 'Maximized', FDashboardMaximized);
    FUpdateEnabled := Ini.ReadBool('Update', 'Enabled', FUpdateEnabled);
    FUpdateLastNotified := Trim(Ini.ReadString('Update', 'LastNotified', FUpdateLastNotified));
    FUpdateLatestKnown := Trim(Ini.ReadString('Update', 'LatestKnown', FUpdateLatestKnown));
  finally
    Ini.Free;
  end;
  Normalize;
end;

procedure TAppSettings.Save;
var
  Ini: TMemIniFile;
  Dir: string;
begin
  Normalize;
  Dir := ExtractFilePath(FFilePath);
  if not DirectoryExists(Dir) then
    ForceDirectories(Dir);

  if SameText(FFilePath, ExeIniPath) and (not CanWriteDir(Dir)) then
  begin
    FFilePath := AppDataIniPath;
    ForceDirectories(ExtractFilePath(FFilePath));
  end;

  Ini := TMemIniFile.Create(FFilePath);
  try
    Ini.WriteString('General', 'Mode', FMode);
    Ini.WriteBool('General', 'StayOnTop', FStayOnTop);
    Ini.WriteInteger('General', 'Fps', FFps);
    Ini.WriteInteger('General', 'WindowX', FWindowX);
    Ini.WriteInteger('General', 'WindowY', FWindowY);
    Ini.WriteBool('General', 'Startup', FStartup);
    Ini.WriteBool('View', 'Compact', FCompact);
    Ini.WriteFloat('View', 'GraphRateHz', FGraphRateHz);
    if FSpeedScale = ssLog then
      Ini.WriteString('View', 'SpeedScale', 'log')
    else
      Ini.WriteString('View', 'SpeedScale', 'linear');
    Ini.WriteBool('Ping', 'Enabled', FPingEnabled);
    Ini.WriteInteger('Ping', 'IntervalSec', FPingIntervalSec);
    Ini.WriteBool('Ping', 'AutoGateway', FPingAutoGateway);
    Ini.WriteString('Ping', 'Host', FPingHost);
    Ini.WriteInteger('Ping', 'ThresholdFairMs', FPingFairMs);
    Ini.WriteInteger('Ping', 'ThresholdSlowMs', FPingSlowMs);
    Ini.WriteInteger('Ping', 'ThresholdTimeoutMs', FPingTimeoutMs);
    Ini.WriteBool('Dashboard', 'Open', FDashboardOpen);
    Ini.WriteInteger('Dashboard', 'WindowX', FDashboardX);
    Ini.WriteInteger('Dashboard', 'WindowY', FDashboardY);
    Ini.WriteInteger('Dashboard', 'WindowW', FDashboardW);
    Ini.WriteInteger('Dashboard', 'WindowH', FDashboardH);
    Ini.WriteBool('Dashboard', 'Maximized', FDashboardMaximized);
    Ini.WriteBool('Update', 'Enabled', FUpdateEnabled);
    Ini.WriteString('Update', 'LastNotified', FUpdateLastNotified);
    Ini.WriteString('Update', 'LatestKnown', FUpdateLatestKnown);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
