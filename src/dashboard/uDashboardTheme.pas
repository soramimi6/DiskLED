unit uDashboardTheme;

interface

uses
  Vcl.Graphics;

type
  THudPalette = record
    Bg: TColor;
    Card: TColor;
    CardBorder: TColor;
    Grid: TColor;
    TextPrimary: TColor;
    TextMuted: TColor;
    AccentStart: TColor;
    AccentEnd: TColor;
    Cpu: TColor;
    Mem: TColor;
    Swap: TColor;
    Disk: TColor;
    DiskInner: TColor;
    Net: TColor;
    NetInner: TColor;
    MemStandby: TColor;
    MemFree: TColor;
    Active: TColor;
    Skip: TColor;
    PingOk: TColor;
    PingFair: TColor;
    PingSlow: TColor;
    PingTimeout: TColor;
    GraphFillAlpha: Byte;
  end;

  THudMetrics = record
    Margin: Integer;
    HeaderHeight: Integer;
    AccentLine: Integer;
    CardRadius: Integer;
    CardGap: Integer;
    CardPad: Integer;
    StatPillHeight: Integer;
    GraphHeight: Integer;
    CardHeaderHeight: Integer;
    MeterPaneWidth: Integer;
    SideColWidth: Integer;
    NicRowHeight: Integer;
    PingHeroHeight: Integer;
    PingRowHeight: Integer;
    BigDigitSize: Integer;
    HeadingSize: Integer;
    BodySize: Integer;
    MonoSize: Integer;
    AxisSize: Integer;
  end;

function SystemUsesLightTheme: Boolean;
procedure ApplyHudTitleBar(AHandle: THandle);
function HudPaletteDark: THudPalette;
function HudPaletteLight: THudPalette;
function HudPalette: THudPalette;
function HudMetrics: THudMetrics;
function PingLevelColor(const APalette: THudPalette; ALevel: Integer): TColor;

implementation

uses
  Winapi.Windows,
  uMetricsTypes;

function DwmSetWindowAttribute(hwnd: HWND; dwAttribute: DWORD;
  pvAttribute: Pointer; cbAttribute: DWORD): HRESULT; stdcall;
  external 'dwmapi.dll' name 'DwmSetWindowAttribute';

function SystemUsesLightTheme: Boolean;
var
  Key: HKEY;
  Data, DataSize, Typ: DWORD;
begin
  { Default to dark so the existing HUD look is kept if the key is missing. }
  Result := False;
  Data := 0;
  DataSize := SizeOf(Data);
  Typ := REG_DWORD;
  if RegOpenKeyEx(HKEY_CURRENT_USER,
    'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    0, KEY_READ, Key) <> ERROR_SUCCESS then
    Exit;
  try
    if RegQueryValueEx(Key, 'AppsUseLightTheme', nil, @Typ, @Data, @DataSize) =
      ERROR_SUCCESS then
      Result := Data <> 0;
  finally
    RegCloseKey(Key);
  end;
end;

procedure ApplyHudTitleBar(AHandle: THandle);
const
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;
  DWMWA_USE_IMMERSIVE_DARK_MODE_OLD = 19;
var
  Dark: BOOL;
begin
  if AHandle = 0 then
    Exit;
  Dark := not SystemUsesLightTheme;
  DwmSetWindowAttribute(HWND(AHandle), DWMWA_USE_IMMERSIVE_DARK_MODE, @Dark,
    SizeOf(Dark));
  DwmSetWindowAttribute(HWND(AHandle), DWMWA_USE_IMMERSIVE_DARK_MODE_OLD, @Dark,
    SizeOf(Dark));
end;

function HudPaletteDark: THudPalette;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Bg := $170F0B;
  Result.Card := $261812;
  Result.CardBorder := $443024;
  Result.Grid := $30221A;
  Result.TextPrimary := $F6EDE6;
  Result.TextMuted := $A38B7B;
  { RGB() is TColor ($00BBGGRR). Values below were authored as #RRGGBB. }
  Result.AccentStart := RGB($D4, $00, $00);
  Result.AccentEnd := RGB($5C, $7B, $00);
  Result.Cpu := RGB($9F, $3B, $00);
  Result.Mem := RGB($87, $DB, $3D);
  Result.Swap := RGB($FF, $CB, $6B);
  Result.Disk := RGB($42, $8C, $FF);
  Result.DiskInner := RGB($66, $D1, $FF);
  Result.Net := RGB($FF, $7C, $B4);
  Result.NetInner := RGB($FF, $B0, $D4);
  Result.MemStandby := RGB($5A, $8C, $C8);
  Result.MemFree := RGB($5C, $4A, $3E);
  Result.Active := RGB($C0, $E5, $00);
  Result.Skip := RGB($80, $6B, $5C);
  Result.PingOk := RGB($87, $DB, $3D);
  Result.PingFair := RGB($66, $D1, $FF);
  Result.PingSlow := RGB($42, $8C, $FF);
  Result.PingTimeout := RGB($6D, $4D, $FF);
  Result.GraphFillAlpha := 80;
end;

function HudPaletteLight: THudPalette;
begin
  { Provisional light set: same hues as dark, darkened for a warm paper ground. }
  FillChar(Result, SizeOf(Result), 0);
  Result.Bg := RGB($F4, $EE, $E8);
  Result.Card := RGB($FF, $FC, $F9);
  Result.CardBorder := RGB($D2, $C2, $B4);
  Result.Grid := RGB($E6, $DC, $D4);
  Result.TextPrimary := RGB($1C, $14, $10);
  Result.TextMuted := RGB($6E, $5A, $4E);
  Result.AccentStart := RGB($D4, $00, $00);
  Result.AccentEnd := RGB($5C, $7B, $00);
  Result.Cpu := RGB($B3, $42, $00);
  Result.Mem := RGB($3F, $8C, $14);
  Result.Swap := RGB($C4, $88, $12);
  Result.Disk := RGB($16, $3C, $B8);
  Result.DiskInner := RGB($0A, $8A, $88);
  Result.Net := RGB($8E, $0A, $68);
  Result.NetInner := RGB($EE, $86, $00);
  Result.MemStandby := RGB($3A, $6A, $B0);
  Result.MemFree := RGB($E8, $E0, $D8);
  Result.Active := RGB($6B, $8C, $00);
  Result.Skip := RGB($7A, $68, $5C);
  Result.PingOk := RGB($3F, $8C, $14);
  Result.PingFair := RGB($0D, $7A, $A8);
  Result.PingSlow := RGB($1E, $5E, $D4);
  Result.PingTimeout := RGB($5A, $3A, $C4);
  Result.GraphFillAlpha := 56;
end;

function HudPalette: THudPalette;
begin
  if SystemUsesLightTheme then
    Result := HudPaletteLight
  else
    Result := HudPaletteDark;
end;

function HudMetrics: THudMetrics;
begin
  Result.Margin := 12;
  Result.HeaderHeight := 44;
  Result.AccentLine := 2;
  Result.CardRadius := 8;
  Result.CardGap := 8;
  Result.CardPad := 10;
  Result.StatPillHeight := 96;
  Result.GraphHeight := 88;
  Result.CardHeaderHeight := 22;
  Result.MeterPaneWidth := 240;
  Result.SideColWidth := 360;
  Result.NicRowHeight := 46;
  Result.PingHeroHeight := 28;
  Result.PingRowHeight := 18;
  Result.BigDigitSize := 22;
  Result.HeadingSize := 10;
  Result.BodySize := 10;
  Result.MonoSize := 10;
  Result.AxisSize := 8;
end;

function PingLevelColor(const APalette: THudPalette; ALevel: Integer): TColor;
begin
  case TPingLevel(ALevel) of
    plNormal: Result := APalette.PingOk;
    plFair: Result := APalette.PingFair;
    plSlow: Result := APalette.PingSlow;
  else
    Result := APalette.PingTimeout;
  end;
end;

end.
