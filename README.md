# DiskLED

[English](#diskled-english)

Windows XP 時代に Delphi 4.0 で作られた常駐モニター（HDD / ネットワーク / CPU / メモリ）を、現代の Windows（Windows 11 など）向けに基本設計から再構築したアプリケーションです。

## 確定方針

- **開発環境**: Delphi Community Edition（個人開発・無料配布）／**VCL**・64-bit
- **対象**: Windows 10 / 11
- **外観**: ユーザー導入の旧スキン（`.dla`）は非対応。内部は **layout.cfg ベースの表示モード**（Original / Crystal / Metalic）。`assets/<id>/layout.cfg` を足せばモード追加可能
- **スキンリソース**: 旧版から引き継いだ画像を `assets/original`・`assets/crystal`・`assets/metalic` に配置（座標は各 `layout.cfg`）。`assets/` 以下は旧版開発者と同一の著作物
- **更新頻度**: 最低 **10 fps**、デフォルト **15 fps**。見た目のコマが変わらないときは再描画しない
- **プロセス**: **単一起動のみ**（2つ目以降は起動を抑制し、既存へフォーカス等）
- **スケール**:
  - CPU / 物理メモリ / SWAP … 0～100%
  - ディスク／ネット速度 … デバイス上限 → だめなら実測オートセンス（手動レンジは二期）
  - Ping … 応答時間を 4 段階（正常／やや遅い／遅い／タイムアウト）で表示
- **非採用**: ユーザー向けスキン配布（`.dla`）、SSTP、**サウンド全般**、フローティング、複数起動
- **Phase5**: コンパクト／フル切替（ダブルクリック）と CPU／MEM／SWAP 推移グラフ（Original / Metalic）
- **Phase6**: ユーザー権限インストーラー（Inno Setup）＋ポータブル zip（`tools/make-*.ps1`）

## MVP（第1版）

「今アクセスしているか／どのくらい負荷か」が一目で分かる常駐デスクトップガジェット。単独アプリケーションとして必要最小限の機能を備えた初版。

**含める**

- 表示モード切替（Original / Crystal / Metalic）
- CPU、MEM、SWAP（仮想メモリ）メーター
- Disk R/W LED＋速度バー
- Net 送受信 LED＋速度バー
- **Ping 表示**（両モード）
- 最前面表示機能
- 設定の簡易永続化（ini）
- トレイアイコン（起動中）表示
- スタートアップ登録機能
- 単一起動の強制

**含めない（今後検討）**

- フローティング
- サウンド
- 複数起動・ドライブ別インスタンス
- マウス接近で隠す／最大化でトレイ退避
- OwnerDraw メニュー
- 高 DPI 本対応（Per-Monitor v2）
- 手動速度レンジ UI
- 手動言語切替（ini / メニュー）

フル／コンパクト＋推移グラフは **Phase5（実装済み）**。Crystal はコンパクトのみ。

### 監視対象

- **ディスク**: 全物理ディスクの I/O を**合算**（システム全体の「HDDランプ」相当）
- **ネットワーク**: **実 NIC のみ合算**（VPN・ループバック・仮想アダプタは除外を試みる）
- **Ping**: 指定ホスト（既定 **mg6.jp**）、またはデフォルトゲートウェイ自動検出。間隔は **最低 5 分**、閾値はオプションで変更可

### UI・描画

- **透過**: 旧スキン同様、カラーキー透過で非矩形ウィンドウを再現する
- **設定ファイル**: 基本は exe と同じフォルダの `DiskLED.ini`（書込不可時は `%AppData%\DiskLED\DiskLED.ini` へフォールバックする）
- **メーター追従**: 上昇は指数で速く、下降は定速の余韻（fps 非依存）。動きは表示モードの `layout.cfg` `[Ballistic]` で指定（作業版 3.0.1。公開リリースは後続版）
- **対数スケール**: ネット速度はオプションで直線（既定）または対数。ディスクはオートセンスの直線。CPU／MEM／SWAP は常に直線
- **高 DPI**: 初版は **100% 表示前提**（拡大時は OS 側拡大でも可）
- **権限**: **管理者不要**で動く範囲に限定（ICMP Ping も一般権限で実施）

### 配布・その他

- **配布形態**:
  - 正式配布は **Inno Setup インストーラー**（`DiskLED_Setup_3.0.0.exe`、ユーザー権限・既定 `%LocalAppData%\Programs\DiskLED`）
  - 併せてポータブル zip（`DiskLED-3.0.0-portable.zip`）も利用可能とする
- **言語**: 既定は英語。OS の UI 言語が日本語のときだけ日本語
- **ライセンス**: 著作権は SoRaMiMi（旧版開発者と同一）。`assets/` 以下も同様。公式配布物は無償利用可。ソースの改変・再配布は不可。改善・デバッグの協力は共同開発者（リポジトリ編集権限の付与）として行う。詳細は `LICENSE.txt`

## 想定機能（MVP）

- CPU／物理メモリ／SWAP のリアルタイム表示
- ディスク I/O（LED・速度バー）
- ネットワーク送受信（LED・速度バー）
- Ping（応答段階表示・手動即時更新）
- 速度レンジの自動決定（デバイス情報 → 実測推定）
- 表示モード切替（`assets/*/layout.cfg`。今後追加可）
- 最前面・トレイアイコン・スタートアップ
- 単一起動の抑制
- 設定の ini 保存

## 参考

- 利用者向け説明: `public_docs/`（日本語）と `public_docs/EN/`（英語）
- 表示モード定義: `assets/LAYOUT.md`
- ビルド補助: `tools/build.ps1`（**Community Edition は CLI コンパイル不可**。IDE の F9 / Shift+F9 が正）
- インストーラー: `installer/DiskLED.iss`、`tools/make-installer.ps1` / `tools/make-portable.ps1`

---

# DiskLED (English)

[日本語](#diskled)

This application rebuilds a resident monitor (HDD / network / CPU / memory) originally written in Delphi 4.0 in the Windows XP era, from a fresh design for modern Windows (Windows 11 and others).

## Confirmed policy

- **Development environment**: Delphi Community Edition (personal development, free distribution) / **VCL** · 64-bit
- **Target**: Windows 10 / 11
- **Appearance**: User-supplied legacy skins (`.dla`) are not supported. Internally, display modes are **layout.cfg-based** (Original / Crystal / Metalic). Modes can be added by placing `assets/<id>/layout.cfg`
- **Skin resources**: Images inherited from the previous version live in `assets/original`, `assets/crystal`, and `assets/metalic` (coordinates are in each `layout.cfg`). Everything under `assets/` is the same copyrighted work as the previous version
- **Refresh rate**: Minimum **10 fps**, default **15 fps**. The window is not redrawn while sprite frames stay the same
- **Process**: **Single instance only** (later launches are suppressed and focus is given to the existing instance, etc.)
- **Scales**:
  - CPU / physical memory / SWAP … 0–100%
  - Disk / network speed … device maximum → if that fails, measured auto-sense (manual range is a later phase)
  - Ping … response time shown in 4 levels (OK / somewhat slow / slow / timeout)
- **Not adopted**: User-facing skin distribution (`.dla`), SSTP, **sound in general**, floating, multiple instances
- **Phase5**: Compact/full toggle (double-click) and CPU / MEM / SWAP history graphs (Original / Metalic)
- **Phase6**: Per-user installer (Inno Setup) + portable zip (`tools/make-*.ps1`)

## MVP (first edition)

A resident desktop gadget that shows at a glance whether something is being accessed and how much load there is. First edition with the minimum features needed as a standalone application.

**Include**

- Display mode switching (Original / Crystal / Metalic)
- CPU, MEM, SWAP (virtual memory) meters
- Disk R/W LED + speed bar
- Net in/out LEDs + speed bar
- **Ping display** (both modes)
- Always-on-top
- Simple settings persistence (ini)
- Tray icon (while running)
- Startup registration
- Enforce single instance

**Do not include (consider later)**

- Floating
- Sound
- Multiple instances / per-drive instances
- Hide on mouse approach / retreat to tray when maximized
- OwnerDraw menus
- Full high-DPI support (Per-Monitor v2)
- Manual speed-range UI
- Manual language switching (ini / menu)

Full/compact + history graphs are **Phase5 (implemented)**. Crystal is compact-only.

### What is monitored

- **Disk**: **Sum** of I/O of all physical disks (system-wide “HDD lamp” equivalent)
- **Network**: **Sum of real NICs only** (VPN, loopback, and virtual adapters are excluded where possible)
- **Ping**: Specified host (default **mg6.jp**), or auto-detect the default gateway. Interval is **at least 5 minutes**; thresholds can be changed in Options

### UI / drawing

- **Transparency**: Color-key transparency, like the old skins, to reproduce a non-rectangular window
- **Settings file**: Basically `DiskLED.ini` in the same folder as the exe (falls back to `%AppData%\DiskLED\DiskLED.ini` when that folder is not writable)
- **Meter follow**: Fast exponential rise, constant-speed fall (fps-independent). Motion is set per display mode in `layout.cfg` `[Ballistic]` (dev build 3.0.1; public release in a later version)
- **Log scale**: Network speed can be linear (default) or logarithmic in Options. Disk stays auto-sense linear. CPU / MEM / SWAP stay linear
- **High DPI**: First edition assumes **100% display scale** (OS scaling is acceptable when enlarged)
- **Privileges**: Limited to what works **without administrator** (ICMP Ping is also done as a standard user)

### Distribution and other

- **Distribution**:
  - Official distribution is the **Inno Setup installer** (`DiskLED_Setup_3.0.0.exe`, per-user, default `%LocalAppData%\Programs\DiskLED`)
  - A portable zip (`DiskLED-3.0.0-portable.zip`) is also available
- **Language**: English by default. Japanese only when the OS UI language is Japanese
- **License**: Copyright is SoRaMiMi (same as the previous version’s author). Same for `assets/`. Official packages may be used free of charge. Modification and redistribution of the source are not permitted. Help with improvements and debugging is as a co-developer (granted repository write access). Details in `LICENSE.txt`

## Intended features (MVP)

- Real-time CPU / physical memory / SWAP display
- Disk I/O (LED · speed bar)
- Network send/receive (LED · speed bar)
- Ping (level display · manual immediate refresh)
- Automatic speed range (device info → measured estimate)
- Display mode switching (`assets/*/layout.cfg`; more can be added later)
- Always-on-top, tray icon, startup
- Suppress extra instances
- Settings saved to ini

## References

- End-user docs: `public_docs/` (Japanese) and `public_docs/EN/` (English)
- Display mode definition: `assets/LAYOUT.md`
- Build helper: `tools/build.ps1` (**Community Edition cannot compile from the command line**. IDE F9 / Shift+F9 is authoritative)
- Installer: `installer/DiskLED.iss`, `tools/make-installer.ps1` / `tools/make-portable.ps1`
