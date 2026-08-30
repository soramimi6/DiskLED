unit uAppStrings;

{ UI / error strings. Default English; Japanese when the OS UI language is Japanese.
  Manual override is out of scope for now (ini Language= later). }

interface

type
  TAppLang = (alJapanese, alEnglish);

procedure InitAppLanguage;
function AppLanguage: TAppLang;
function S(const AId: string): string;
function GetProductVersionText: string;

implementation

uses
  Winapi.Windows,
  System.SysUtils;

type
  TStrEntry = record
    Id: string;
    Ja: string;
    En: string;
  end;

var
  CStrings: array of TStrEntry;
  GLang: TAppLang = alEnglish;
  GInitialized: Boolean = False;
  GStringsReady: Boolean = False;

procedure AddStr(const AId, AJa, AEn: string);
var
  n: Integer;
begin
  n := Length(CStrings);
  SetLength(CStrings, n + 1);
  CStrings[n].Id := AId;
  CStrings[n].Ja := AJa;
  CStrings[n].En := AEn;
end;

procedure EnsureStrings;
begin
  if GStringsReady then
    Exit;

  AddStr('menu.ping', 'Ping 更新', 'Refresh Ping');
  AddStr('menu.dashboard', 'ダッシュボード', 'Dashboard');
  AddStr('menu.compact', 'コンパクト', 'Compact');
  AddStr('menu.full', 'フル', 'Full');
  AddStr('menu.exit', '終了', 'Exit');
  AddStr('menu.options', 'オプション', 'Options');
  AddStr('hover.ping_off', 'オフ', 'off');
  AddStr('hover.ping_timeout', 'タイムアウト', 'timeout');
  AddStr('hover.ping_pending', '…', '…');

  AddStr('opt.title', 'DiskLED オプション', 'DiskLED Options');
  AddStr('opt.group.window', 'ウィンドウ', 'Window');
  AddStr('opt.group.ping', 'Ping', 'Ping');
  AddStr('opt.group.thresholds', 'Ping 判定しきい値', 'Ping level thresholds');
  AddStr('opt.stay_on_top', '常に手前に表示', 'Always on top');
  AddStr('opt.startup', 'スタートアップに登録', 'Run at Windows startup');
  AddStr('opt.fps', '表示頻度 (fps)', 'Refresh rate (fps)');
  AddStr('opt.graph_rate', 'グラフ更新 (Hz)', 'Graph update (Hz)');
  AddStr('opt.speed_scale', 'ネット速度の反応', 'Network speed response');
  AddStr('opt.speed_scale_linear', '直線（リンク速度＝100%）', 'Linear (link speed = 100%)');
  AddStr('opt.speed_scale_log', '対数（小さい通信も振れやすい）', 'Logarithmic (small traffic more visible)');
  AddStr('opt.ping_enabled', 'Ping を有効にする', 'Enable Ping');
  AddStr('opt.ping_auto_gw', 'デフォルトゲートウェイを使う', 'Use default gateway');
  AddStr('opt.ping_host', 'Ping ホスト', 'Ping host');
  AddStr('opt.ping_interval', '間隔 (秒, 最低 300)', 'Interval (sec, min 300)');
  AddStr('opt.ping_fair', 'やや遅い閾値 (ms)', 'Fair threshold (ms)');
  AddStr('opt.ping_slow', '遅い閾値 (ms)', 'Slow threshold (ms)');
  AddStr('opt.ping_timeout', 'タイムアウト閾値 (ms)', 'Timeout threshold (ms)');
  AddStr('opt.ping_fair_short', 'やや遅い (ms)', 'Fair (ms)');
  AddStr('opt.ping_slow_short', '遅い (ms)', 'Slow (ms)');
  AddStr('opt.ping_timeout_short', 'タイムアウト', 'Timeout');
  AddStr('opt.ping_reset_thresholds', 'しきい値をデフォルトにリセット', 'Reset thresholds to defaults');
  AddStr('opt.err.interval_number',
    'Ping 間隔には整数を入力してください。',
    'Enter a whole number for the Ping interval.');
  AddStr('opt.err.interval_min',
    'Ping 間隔は %d 秒以上にしてください。',
    'Ping interval must be at least %d seconds.');
  AddStr('opt.err.threshold_number',
    'Ping 判定しきい値には整数を入力してください。',
    'Enter whole numbers for Ping level thresholds.');
  AddStr('opt.err.threshold_positive',
    'Ping 判定しきい値は 1 以上にしてください。',
    'Ping level thresholds must be 1 or greater.');
  AddStr('opt.err.threshold_order',
    'しきい値は「やや遅い < 遅い < タイムアウト」の順にしてください。',
    'Thresholds must satisfy Fair < Slow < Timeout.');
  AddStr('opt.apply', '適用', 'Apply');
  AddStr('opt.cancel', 'キャンセル', 'Cancel');

  AddStr('err.image_not_found', '画像が見つかりません: %s', 'Image not found: %s');
  AddStr('err.image_name_empty', '画像ファイル名が空です。', 'Image file name is empty.');
  AddStr('err.assets_not_found',
    'assets フォルダ（layout.cfg 付き）が見つかりません。exe と同じ階層、またはプロジェクト直下に assets を置いてください。',
    'assets folder with layout.cfg not found. Place assets next to the exe, or under the project root.');
  AddStr('err.assets_dir_missing', 'assets が見つかりません: %s', 'assets not found: %s');
  AddStr('err.mode_id_duplicate', '表示モード ID が重複しています: %s', 'Duplicate display mode ID: %s');
  AddStr('err.no_display_modes',
    '表示モードがありません。assets 配下に layout.cfg を配置してください。',
    'No display modes. Place layout.cfg under assets.');
  AddStr('err.mode_index_out_of_range', '表示モードの番号が範囲外です。', 'Display mode index is out of range.');
  AddStr('err.unknown_mode', '未知の表示モードです: %s', 'Unknown display mode: %s');
  AddStr('err.no_modes_registered', '表示モードが1つも登録されていません。', 'No display modes are registered.');
  AddStr('err.layout_mode_incomplete',
    'layout.cfg の Mode 定義が不完全です: %s',
    'Incomplete Mode section in layout.cfg: %s');

  AddStr('dash.title', 'DiskLED ダッシュボード', 'DiskLED Dashboard');
  AddStr('dash.cpu', 'CPU', 'CPU');
  AddStr('dash.cpu_user', 'User', 'User');
  AddStr('dash.cpu_kernel', 'Kernel', 'Kernel');
  AddStr('dash.cpu_name', '名前', 'Name');
  AddStr('dash.cpu_cores', 'コア', 'Cores');
  AddStr('dash.cpu_clock', 'クロック', 'Clock');
  AddStr('dash.mem', 'メモリ', 'Memory');
  AddStr('dash.swap', 'SWAP', 'SWAP');
  AddStr('dash.disk_read', 'ディスク読取', 'Disk Read');
  AddStr('dash.disk_write', 'ディスク書込', 'Disk Write');
  AddStr('dash.disk', 'ディスク', 'Disk');
  AddStr('dash.net', 'ネット', 'Net');
  AddStr('dash.net_in', 'ネット受信', 'Net In');
  AddStr('dash.net_out', 'ネット送信', 'Net Out');
  AddStr('dash.ram', 'RAM', 'RAM');
  AddStr('dash.mem_avail', '空き', 'Avail');
  AddStr('dash.mem_cache', 'キャッシュ', 'Cache');
  AddStr('dash.mem_commit', 'コミット', 'Commit');
  AddStr('dash.mem_used', '使用中', 'In use');
  AddStr('dash.mem_standby', 'スタンバイ', 'Standby');
  AddStr('dash.mem_free', '空き', 'Free');
  AddStr('dash.lg_read', '読取', 'Read');
  AddStr('dash.lg_write', '書込', 'Write');
  AddStr('dash.lg_in', 'In', 'In');
  AddStr('dash.lg_out', 'Out', 'Out');
  AddStr('dash.disk_active', 'アクティブ', 'Active');
  AddStr('dash.queue', 'ディスクキュー', 'Disk queue');
  AddStr('dash.queue_depth', 'Queue', 'Queue');
  AddStr('dash.iops_read', '読取 IOPS', 'Read IOPS');
  AddStr('dash.iops_write', '書込 IOPS', 'Write IOPS');
  AddStr('dash.power', '電源', 'Power');
  AddStr('dash.power_source', 'ソース', 'Source');
  AddStr('dash.power_ac', 'AC', 'AC');
  AddStr('dash.power_battery', 'バッテリ', 'Battery');
  AddStr('dash.power_unknown', '不明', 'Unknown');
  AddStr('dash.power_remain', '残時間', 'Remaining');
  AddStr('dash.dhcp', 'DHCP', 'DHCP');
  AddStr('dash.static', '固定', 'Static');
  AddStr('dash.gw', 'GW', 'GW');
  AddStr('dash.disk_note', '全物理ディスク（合算）', 'All physical disks (aggregate)');
  AddStr('dash.adapters', 'アダプタ', 'Adapters');
  AddStr('dash.nic_active', '稼働中', 'Active');
  AddStr('dash.nic_skip', '除外', 'Skip');
  AddStr('dash.ping', 'Ping', 'Ping');
  AddStr('dash.ping_time', '時刻', 'Time');
  AddStr('dash.ping_target', '宛先', 'Target');
  AddStr('dash.ping_rtt', 'RTT', 'RTT');
  AddStr('dash.ping_status', '状態', 'Status');
  AddStr('dash.live', 'LIVE', 'LIVE');
  AddStr('dash.axis_now', '現在', 'now');
  AddStr('dash.axis_5m', '5分', '5m');

  GStringsReady := True;
end;

function IsJapaneseUi: Boolean;
var
  Lang: LANGID;
begin
  Lang := GetUserDefaultUILanguage;
  Result := (Lang and $3FF) = LANG_JAPANESE;
end;

procedure InitAppLanguage;
begin
  EnsureStrings;
  if IsJapaneseUi then
    GLang := alJapanese
  else
    GLang := alEnglish;
  GInitialized := True;
end;

function AppLanguage: TAppLang;
begin
  if not GInitialized then
    InitAppLanguage;
  Result := GLang;
end;

function S(const AId: string): string;
var
  i: Integer;
begin
  EnsureStrings;
  if not GInitialized then
    InitAppLanguage;
  for i := 0 to High(CStrings) do
    if SameText(CStrings[i].Id, AId) then
    begin
      if GLang = alJapanese then
        Exit(CStrings[i].Ja);
      Exit(CStrings[i].En);
    end;
  Result := AId;
end;

function GetProductVersionText: string;
const
  CFallback = '3.0.1';
var
  Path: string;
  Size: DWORD;
  Handle: DWORD;
  Buf: Pointer;
  Len: UINT;
  Info: PVSFixedFileInfo;
  Maj, Min, Rel, Bld: Word;
begin
  Result := CFallback;
  Path := ParamStr(0);
  Size := GetFileVersionInfoSize(PChar(Path), Handle);
  if Size = 0 then
    Exit;
  GetMem(Buf, Size);
  try
    if not GetFileVersionInfo(PChar(Path), Handle, Size, Buf) then
      Exit;
    if not VerQueryValue(Buf, '\', Pointer(Info), Len) then
      Exit;
    if (Info = nil) or (Len < SizeOf(TVSFixedFileInfo)) then
      Exit;
    Maj := HiWord(Info.dwFileVersionMS);
    Min := LoWord(Info.dwFileVersionMS);
    Rel := HiWord(Info.dwFileVersionLS);
    Bld := LoWord(Info.dwFileVersionLS);
    if Bld = 0 then
      Result := Format('%d.%d.%d', [Maj, Min, Rel])
    else
      Result := Format('%d.%d.%d.%d', [Maj, Min, Rel, Bld]);
  finally
    FreeMem(Buf);
  end;
end;

initialization
  EnsureStrings;

end.
