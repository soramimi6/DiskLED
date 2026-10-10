unit uAppStrings;

{ UI / error strings. The active language is picked once at startup: the ini
  [General] Language preference ('ja' / 'en') wins, otherwise ('auto' / unset)
  it follows the OS UI language. Future languages slot into TAppLang and fall
  back to English for any string left untranslated. }

interface

type
  { Order is the ini/display order for the manual picker; alEnglish is the
    fallback tongue, so keep it valid for every entry. Future: alGerman,
    alChineseTraditional. }
  TAppLang = (alJapanese, alEnglish);

{ APref: 'ja' / 'en' force that language; 'auto' or '' follows the OS. }
procedure InitAppLanguage(const APref: string = '');
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
    Text: array[TAppLang] of string;
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
  CStrings[n].Text[alJapanese] := AJa;
  CStrings[n].Text[alEnglish] := AEn;
end;

procedure EnsureStrings;
begin
  if GStringsReady then
    Exit;

  AddStr('menu.dashboard', 'ダッシュボード', 'Dashboard');
  AddStr('menu.compact', 'コンパクト', 'Compact');
  AddStr('menu.full', 'フル', 'Full');
  AddStr('menu.window_only', 'ウィンドウのみ', 'Window Only');
  AddStr('menu.window_tray_led', 'ウィンドウ＋トレイ LED', 'Window + Tray LED');
  AddStr('menu.tray_only', 'トレイ LED のみ', 'Tray LED Only');
  AddStr('menu.scale', '表示倍率', 'Display Scale');
  AddStr('menu.scale_auto', '自動', 'Auto');
  AddStr('menu.exit', '終了', 'Exit');
  AddStr('menu.options', 'オプション', 'Options');
  AddStr('menu.reset_position', '位置をリセット', 'Reset Position');
  AddStr('menu.update', '新しい DiskLED %s の情報を見る', 'View DiskLED %s release info');
  AddStr('tray.update_title', 'DiskLED からのお知らせ', 'A notice from DiskLED');
  AddStr('tray.update', 'DiskLED %s が公開されています', 'DiskLED %s is available');
  AddStr('tray.hint_net', 'DiskLED ネットアクセス', 'DiskLED Network activity');
  AddStr('opt.window_mode', '表示モード', 'Display mode');
  AddStr('tray.drive_rate', '%s: 読込 %s ・ 書込 %s', '%s: Read %s · Write %s');
  AddStr('hover.ping_off', 'オフ', 'off');
  AddStr('hover.ping_timeout', 'タイムアウト', 'timeout');
  AddStr('hover.ping_pending', '…', '…');


  AddStr('opt.title', 'DiskLED オプション', 'DiskLED Options');
  AddStr('opt.tab.general', '全般', 'General');
  AddStr('opt.tab.display', '表示', 'Display');
  AddStr('opt.tab.tray_led', 'トレイ LED', 'Tray LED');
  { The && is a literal & once VCL strips the Caption accelerator marker
    (TTabSheet.Caption, like any VCL Caption, treats a lone & specially). }
  AddStr('opt.tab.ping', 'Ping・ネットワーク', 'Ping && Network');
  AddStr('opt.group.window', 'ウィンドウ', 'Window');
  AddStr('opt.language', '表示言語', 'Language');
  AddStr('opt.language_restart_hint',
    '再起動後に反映されます',
    'Applied after restart');
  AddStr('opt.group.ping', 'Ping', 'Ping');
  AddStr('opt.group.thresholds', 'Ping 判定しきい値', 'Ping level thresholds');
  AddStr('opt.stay_on_top', '常に手前に表示', 'Always on top');
  AddStr('opt.startup', 'スタートアップに登録', 'Run at Windows startup');
  AddStr('opt.startup_blocked',
    'Windows の「スタートアップ アプリ」設定で有効にしてください。',
    'Enable this in Windows Startup Apps settings.');
  AddStr('opt.startup_pending',
    '処理中です。しばらくしてからオプションを開き直してください。',
    'Still processing. Please reopen Options in a moment.');
  AddStr('opt.startup_unknown',
    '現在の登録状態を確認できませんでした。しばらくしてからオプションを開き直してください。',
    'Could not check the current registration state. Please reopen Options in a moment.');
  AddStr('opt.err.startup_task',
    'スタートアップの登録状態を確認できませんでした（Windows の機能呼び出しに失敗）。しばらくしてからもう一度お試しください。',
    'Could not check the Windows startup registration state (a system call failed). Please try again in a moment.');
  AddStr('opt.update_check', '起動時に新しい版を確認する', 'Check for a new version at startup');
  AddStr('opt.fps', '表示頻度 (fps)', 'Refresh rate (fps)');
  AddStr('opt.graph_rate', 'グラフ更新 (Hz)', 'Graph update (Hz)');
  AddStr('opt.speed_scale', 'ネット速度の反応', 'Network speed response');
  AddStr('opt.speed_scale_linear', '直線（リンク速度＝100%）', 'Linear (link speed = 100%)');
  AddStr('opt.speed_scale_log', '対数（小さい通信も振れやすい）', 'Logarithmic (small traffic more visible)');
  AddStr('opt.tray_led_color', 'トレイ LED の色', 'Tray LED color');
  AddStr('opt.tray_led_color_green', '緑', 'Green');
  AddStr('opt.tray_led_color_blue', '青', 'Blue');
  AddStr('opt.tray_led_color_red', '赤', 'Red');
  AddStr('opt.tray_led_color_yellow', '黄', 'Yellow');
  AddStr('opt.tray_led_info', 'トレイ LED の情報', 'Tray LED info');
  AddStr('opt.tray_led_info_disk', 'ディスク', 'Disk');
  AddStr('opt.tray_led_info_net', 'ネットワーク', 'Network');
  AddStr('opt.tray_drives', 'ドライブ別 LED（ツールチップで識別）', 'Per-drive LEDs (identified by tooltip)');
  AddStr('opt.tray_drive_total', '合算 LED も表示する', 'Also show the total LED');
  AddStr('opt.tray_drive_absent', '（未接続）', ' (not connected)');
  AddStr('drive.fixed', '固定', 'Fixed');
  AddStr('drive.removable', 'リムーバブル', 'Removable');
  AddStr('drive.optical', '光学', 'Optical');
  AddStr('drive.network', 'ネットワーク', 'Network');
  AddStr('drive.unsupported', '（非対応）', ' (unsupported)');
  AddStr('opt.ping_enabled', 'Ping を有効にする', 'Enable Ping');
  AddStr('opt.ping_auto_gw', 'デフォルトゲートウェイを使う', 'Use default gateway');
  AddStr('opt.ping_host', 'Ping ホスト', 'Ping host');
  AddStr('opt.ping_interval', '間隔 (秒, 最低 300)', 'Interval (sec, min 300)');
  AddStr('opt.ping_fair', 'やや遅いしきい値 (ms)', 'Fair threshold (ms)');
  AddStr('opt.ping_slow', '遅いしきい値 (ms)', 'Slow threshold (ms)');
  AddStr('opt.ping_timeout', 'タイムアウトしきい値 (ms)', 'Timeout threshold (ms)');
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
  AddStr('err.layout_value_invalid',
    'layout.cfg の値が不正です: %s [%s] %s=%s',
    'Invalid value in layout.cfg: %s [%s] %s=%s');
  AddStr('err.layout_ballistic_required',
    'layout.cfg のメーターパーツに Kind/Strength がありません: %s [%s]',
    'Missing Kind/Strength for a meter part in layout.cfg: %s [%s]');
  AddStr('err.layout_digit_font_required',
    'layout.cfg の数値表示に ValFontFile がありません: %s [%s]',
    'Missing ValFontFile for a bitmap digit readout in layout.cfg: %s [%s]');

  AddStr('dash.title', 'DiskLED ダッシュボード', 'DiskLED Dashboard');
  AddStr('dash.cpu', 'CPU', 'CPU');
  AddStr('dash.gpu', 'GPU', 'GPU');
  AddStr('dash.cpu_gpu', 'CPU / GPU', 'CPU / GPU');
  AddStr('dash.cpu_user', 'ユーザー', 'User');
  AddStr('dash.cpu_kernel', 'カーネル', 'Kernel');
  AddStr('dash.cpu_name', '名前', 'Name');
  AddStr('dash.cpu_cores', 'コア', 'Cores');
  AddStr('dash.cpu_clock', 'クロック', 'Clock');
  AddStr('dash.mem', 'メモリ', 'Memory');
  AddStr('dash.swap', 'SWAP', 'SWAP');
  AddStr('dash.disk_read', 'ディスク読込', 'Disk Read');
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
  AddStr('dash.lg_read', '読込', 'Read');
  AddStr('dash.lg_write', '書込', 'Write');
  AddStr('dash.lg_in', '受信', 'In');
  AddStr('dash.lg_out', '送信', 'Out');
  AddStr('dash.disk_active', 'アクティブ', 'Active');
  AddStr('dash.queue', 'ディスク情報', 'Disk Info');
  AddStr('dash.queue_depth', 'Queue', 'Queue');
  AddStr('dash.queue_word', 'キュー', 'Queue');
  AddStr('dash.iops_read', '読込 IOPS', 'Read IOPS');
  AddStr('dash.iops_write', '書込 IOPS', 'Write IOPS');
  AddStr('dash.latency', 'レイテンシ', 'Latency');
  AddStr('dash.power', '電源', 'Power');
  AddStr('dash.power_source', 'ソース', 'Source');
  AddStr('dash.power_ac', 'AC', 'AC');
  AddStr('dash.power_battery', 'バッテリ', 'Battery');
  AddStr('dash.power_unknown', '不明', 'Unknown');
  AddStr('dash.uptime', '稼働 %s', 'Uptime %s');
  AddStr('dash.uptime_dhm', '%d日 %d時間 %d分', '%dd %dh %dm');
  AddStr('dash.uptime_hm', '%d時間 %d分', '%dh %dm');
  AddStr('dash.cum', 'ディスク累計 読込 %s 書込 %s ・ ネット累計 受信 %s 送信 %s',
    'Disk total Read %s Write %s · Net total In %s Out %s');
  AddStr('dash.power_remain', '残時間', 'Remaining');
  AddStr('dash.power_remain_h', '%d時間', '%dh');
  AddStr('dash.power_remain_m', '%d分', '%dm');
  AddStr('dash.power_remain_hm', '%d時間 %d分', '%dh %dm');
  AddStr('dash.audio', '音量', 'Volume');
  AddStr('dash.audio_l', 'L', 'L');
  AddStr('dash.audio_r', 'R', 'R');
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
  AddStr('dash.tab_overview', '概要', 'Overview');
  AddStr('dash.tab_process', 'プロセス', 'Processes');
  AddStr('dash.tab_route', 'Ping/経路', 'Ping / Route');
  AddStr('dash.route_auto', '自動', 'Auto');
  AddStr('dash.route_min', '%d分', '%dm');
  AddStr('dash.route_now', '今すぐ計測', 'Measure now');
  AddStr('dash.route_hops', '%d ホップ', '%d hops');
  AddStr('dash.route_total', '往復 %s', 'Round trip %s');
  AddStr('dash.route_measured', '計測 %s', 'Measured %s');
  AddStr('dash.route_running', '計測中…', 'Measuring…');
  AddStr('dash.route_unreached', '宛先に到達できませんでした', 'Target not reached');
  AddStr('dash.route_failed', 'エラー（名前解決または通信の初期化に失敗）',
    'Error (name resolution or setup failed)');
  AddStr('dash.route_none', 'まだ計測していません', 'Not measured yet');
  AddStr('dash.route_noreply', '応答なし', 'No reply');
  AddStr('dash.route_minmax', '最小 %s / 最大 %s', 'min %s / max %s');
  AddStr('dash.route_col_host', 'ホスト', 'Host');
  AddStr('dash.route_col_seg', '区間', 'Segment');
  AddStr('dash.route_col_rtt', 'RTT', 'RTT');
  AddStr('dash.route_col_loss', '損失', 'Loss');
  AddStr('dash.route_col_jitter', 'ジッター', 'Jitter');
  AddStr('dash.route_col_delta', '前回比', 'vs last');
  AddStr('dash.route_cls_lan', 'LAN', 'LAN');
  AddStr('dash.route_cls_cgnat', 'CGNAT', 'CGNAT');
  AddStr('dash.route_cls_linklocal', 'リンクローカル', 'Link-local');
  AddStr('dash.route_cls_loopback', 'ループバック', 'Loopback');
  AddStr('dash.route_cls_global', 'グローバル', 'Global');
  AddStr('dash.route_kind_ttl', 'TTL 超過', 'TTL expired');
  AddStr('dash.route_kind_reached', '到達', 'Reached');
  AddStr('dash.route_kind_net', 'ネットワーク到達不能', 'Network unreachable');
  AddStr('dash.route_kind_host', 'ホスト到達不能', 'Host unreachable');
  AddStr('dash.route_kind_proto', 'プロトコル到達不能', 'Protocol unreachable');
  AddStr('dash.route_kind_port', 'ポート到達不能', 'Port unreachable');
  AddStr('dash.route_kind_other', 'その他', 'Other');
  AddStr('dash.route_as', '事業者名を表示', 'Show network operators');
  AddStr('dash.route_tip_operator', '事業者', 'Operator');
  AddStr('dash.route_as_pending', '事業者名を取得中…', 'Looking up operator…');
  AddStr('dash.route_as_unknown', '事業者不明', 'Operator unknown');
  AddStr('dash.route_as_tip',
    '経路上の各ホップを運用しているネットワーク事業者名（AS 番号）を表示します。' + sLineBreak +
    'オンの間、経路上のグローバル IP アドレスを外部の DNS サービス（Team Cymru）に問い合わせます。' +
    sLineBreak + '家庭内 LAN と CGNAT のアドレスは送りません。',
    'Shows the network operator (AS number) running each hop.' + sLineBreak +
    'While on, the route''s global IP addresses are sent to an external DNS service (Team Cymru).' +
    sLineBreak + 'Home LAN and CGNAT addresses are never sent.');
  AddStr('dash.route_leg_range', '最小〜最大', 'Min–max');
  AddStr('dash.route_leg_excess', 'ルーター自身の応答遅れ（経路の遅延ではない）',
    'Router''s own reply delay (not path delay)');
  AddStr('dash.route_tip_addr', 'アドレス', 'Address');
  AddStr('dash.route_tip_other', '他のアドレス', 'Other addresses');
  AddStr('dash.route_tip_class', '区分', 'Class');
  AddStr('dash.route_tip_kind', '応答', 'Reply');
  AddStr('dash.route_tip_replyttl', '応答パケットの TTL', 'Reply TTL');
  AddStr('dash.route_tip_seg', '区間遅延', 'Segment delay');
  AddStr('dash.route_tip_eff', '累積', 'Cumulative');
  AddStr('dash.route_tip_rtt', '最小 / 中央値 / 平均 / 最大', 'Min / median / avg / max');
  AddStr('dash.route_tip_jitter', 'ジッター', 'Jitter');
  AddStr('dash.route_tip_received', '応答 %d / %d（損失 %.0f%%）', 'Replies %d / %d (loss %.0f%%)');
  AddStr('dash.route_tip_delta', '前回比', 'vs last');
  AddStr('dash.route_tip_excess',
    'このルーター自身の応答遅れ %s（後続には持ち越されない遅延で、経路の遅延ではありません）',
    'Own reply delay of this router %s (not carried to later hops, so not path delay)');
  AddStr('dash.proc_cpu', 'CPU使用率の高い順', 'By CPU usage');
  AddStr('dash.proc_mem', 'メモリ使用量の多い順', 'By memory used');
  AddStr('dash.proc_io', 'I/O量の多い順', 'By I/O (read + write)');
  AddStr('dash.proc_col_usage', '使用率', 'Usage');
  AddStr('dash.proc_col_used', '使用量', 'Used');
  AddStr('dash.proc_col_share', '割合', 'Share');
  AddStr('dash.proc_col_read', '読込', 'Read');
  AddStr('dash.proc_col_write', '書込', 'Write');
  AddStr('dash.proc_interval', '更新', 'Refresh');
  AddStr('dash.proc_sec', '%d秒', '%ds');
  AddStr('dash.proc_stop', '停止', 'Stop');
  AddStr('dash.proc_noaccess', '詳細を取得できません', 'Details not available');
  AddStr('dash.proc_user_admin', '%s（管理者）', '%s (admin)');
  AddStr('dash.tip_window', 'ウィンドウ', 'Window');
  AddStr('dash.tip_desc', '説明', 'Description');
  AddStr('dash.tip_product', '製品名', 'Product');
  AddStr('dash.tip_company', '会社名', 'Company');
  AddStr('dash.tip_version', 'バージョン', 'Version');
  AddStr('dash.tip_copyright', '著作権', 'Copyright');
  AddStr('dash.tip_user', 'ユーザー', 'User');
  AddStr('dash.tip_bitness', '種類', 'Type');
  AddStr('dash.tip_commit', 'コミット', 'Commit');
  AddStr('dash.tip_handles', 'ハンドル', 'Handles');
  AddStr('dash.tip_threads', 'スレッド', 'Threads');
  AddStr('dash.tip_path', 'パス', 'Path');
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

procedure InitAppLanguage(const APref: string);
var
  Pref: string;
begin
  EnsureStrings;
  Pref := LowerCase(Trim(APref));
  if Pref = 'ja' then
    GLang := alJapanese
  else if Pref = 'en' then
    GLang := alEnglish
  else if IsJapaneseUi then
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
      Result := CStrings[i].Text[GLang];
      { Untranslated entry in a future language: show English rather than a
        blank. English itself is always populated. }
      if (Result = '') and (GLang <> alEnglish) then
        Result := CStrings[i].Text[alEnglish];
      Exit;
    end;
  Result := AId;
end;

function GetProductVersionText: string;
const
  CFallback = '3.3.0';
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
