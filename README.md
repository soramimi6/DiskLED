# DiskLED

[English](#diskled-english)

Windows XP 時代に Delphi 4.0 で作られた常駐モニター（HDD / ネットワーク / CPU / メモリ）を、現代の Windows（Windows 11 など）向けに基本設計から再構築したアプリケーションです。

## 確定方針

- **開発環境**: Delphi Community Edition（個人開発・無料配布）／**VCL**・64-bit
- **対象**: Windows 10 / 11
- **外観**: ユーザー導入の旧スキン（`.dla`）は非対応。内部は **layout.cfg ベースの表示モード**（Original / Crystal / Metalic / Info Bar）。`assets/<id>/layout.cfg` を足せばモード追加可能
- **スキンリソース**: 旧版から引き継いだ画像を `assets/original`・`assets/crystal`・`assets/metalic` に配置。`assets/infobar` は DiskLED 3 向け新規。座標は各 `layout.cfg`。`assets/` 以下は旧版開発者と同一の著作物
- **更新頻度**: 最低 **10 fps**、デフォルト **15 fps**。見た目のコマが変わらないときは再描画しない
- **プロセス**: **単一起動のみ**（2つ目以降は起動を抑制し、既存へフォーカス等）
- **スケール**:
  - CPU / 物理メモリ / SWAP … 0～100%
  - ディスク／ネット速度 … デバイス上限 → だめなら実測オートセンス（手動レンジは二期）
  - Ping … 応答時間を 4 段階（正常／やや遅い／遅い／タイムアウト）で表示
- **非採用**: ユーザー向けスキン配布（`.dla`）、SSTP、**サウンド全般**、フローティング、複数起動
- **Phase5（実装済み）**: コンパクト／フル切替（ダブルクリック）と CPU／MEM／SWAP 推移グラフ（Original / Metalic）
- **Phase6（実装済み）**: ユーザー権限インストーラー（Inno Setup）＋ポータブル zip（`tools/make-*.ps1`）

## 主な機能

「今アクセスしているか／どのくらい負荷か」が一目で分かる常駐デスクトップガジェット。

- 表示モード切替（Original / Crystal / Metalic / Info Bar）
- 表示サイズ：コンパクト／フル／**タスクトレイ**（トレイアイコン自体がディスクアクセス LED）の排他 3 択（3.1.1〜）
- CPU、MEM、SWAP（仮想メモリ）メーター
- Disk R/W LED＋速度バー、Net 送受信 LED＋速度バー
- **Ping**：応答段階表示。専用ウィンドウで Tracert のようにホップごとの経路（TTL・IP・ホスト名・RTT）を表示（3.1.1〜）
- 最前面表示、トレイアイコン、スタートアップ登録、単一起動の強制
- 右クリックメニューから**位置をリセット**（画面外に外れた本体ウィンドウの復旧、3.1.1〜）
- 設定の簡易永続化（ini）
- **高 DPI（Per-Monitor V2）**。ガジェットは 0.5 刻み、ダッシュボードは実 DPI、オプションは VCL Scaled
- **ダッシュボード**（別ウィンドウ）。CPU／メモリ／SWAP／ディスク／ネットのドーナツ・推移グラフ、**ディスクレイテンシ**（3.1.1〜）、電源（再生音量）、Ping 履歴などを表示
- 起動時の新しい版の通知（GitHub Latest を 1 回確認。Microsoft Store 版では無効、3.1.1〜）

Crystal / Info Bar はコンパクトのみ。

## 今後の検討事項

- フローティング
- サウンド
- 複数起動・ドライブ別インスタンス
- マウス接近で隠す／最大化でトレイ退避
- OwnerDraw メニュー
- 手動速度レンジ UI
- 手動言語切替（ini / メニュー）

### 監視対象

- **ディスク**: 全物理ディスクの I/O を**合算**（システム全体の「HDDランプ」相当）
- **ネットワーク**: **実 NIC のみ合算**（VPN・ループバック・仮想アダプタは除外を試みる）
- **Ping**: 指定ホスト（既定 **mg6.jp**）、またはデフォルトゲートウェイ自動検出。間隔は **最低 5 分**、閾値はオプションで変更可

### UI・描画

- **透過**: 旧スキン同様、カラーキー透過で非矩形ウィンドウを再現する
- **設定ファイル**: 基本は exe と同じフォルダの `DiskLED.ini`（書込不可時は `%AppData%\DiskLED\DiskLED.ini` へフォールバックする）
- **メーター追従**: 上昇は指数で速く、下降は定速の余韻（fps 非依存）。動きは表示モードの `layout.cfg` `[Ballistic]` で指定（3.0.1 以降）
- **対数スケール**: ネット速度はオプションで直線（既定）または対数。ディスクはオートセンスの直線。CPU／MEM／SWAP は常に直線
- **高 DPI**: プロセスは **Per-Monitor V2**。ガジェットは 0.5 刻み（125% は見た目 1.5 倍）。ダッシュボードは実 DPI。オプションは VCL の Scaled
- **権限**: **管理者不要**で動く範囲に限定（ICMP Ping も一般権限で実施）

### 配布・その他

- **配布形態**:
  - 正式配布は **Inno Setup インストーラー**（`DiskLED_Setup_<version>.exe`、ユーザー権限・既定 `%LocalAppData%\Programs\DiskLED`）
  - 併せてポータブル zip（`DiskLED-<version>-portable.zip`）も利用可能とする
- **言語**: 既定は英語。OS の UI 言語が日本語のときだけ日本語
- **ライセンス**: 著作権は SoRaMiMi（旧版開発者と同一）。`assets/` 以下も同様。公式配布物は無償利用可。ソースの改変・再配布は不可。改善・デバッグの協力は共同開発者（リポジトリ編集権限の付与）として行う。詳細は `LICENSE.txt`

## 参考

- 変更履歴: `public_docs/CHANGELOG.md`（日本語）/ `public_docs/EN/CHANGELOG.md`（英語）
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
- **Appearance**: User-supplied legacy skins (`.dla`) are not supported. Internally, display modes are **layout.cfg-based** (Original / Crystal / Metalic / Info Bar). Modes can be added by placing `assets/<id>/layout.cfg`
- **Skin resources**: Images inherited from the previous version live in `assets/original`, `assets/crystal`, and `assets/metalic`. `assets/infobar` is new for DiskLED 3 (coordinates are in each `layout.cfg`). Everything under `assets/` is the same copyrighted work as the previous version
- **Refresh rate**: Minimum **10 fps**, default **15 fps**. The window is not redrawn while sprite frames stay the same
- **Process**: **Single instance only** (later launches are suppressed and focus is given to the existing instance, etc.)
- **Scales**:
  - CPU / physical memory / SWAP … 0–100%
  - Disk / network speed … device maximum → if that fails, measured auto-sense (manual range is a later phase)
  - Ping … response time shown in 4 levels (OK / somewhat slow / slow / timeout)
- **Not adopted**: User-facing skin distribution (`.dla`), SSTP, **sound in general**, floating, multiple instances
- **Phase5 (implemented)**: Compact/full toggle (double-click) and CPU / MEM / SWAP history graphs (Original / Metalic)
- **Phase6 (implemented)**: Per-user installer (Inno Setup) + portable zip (`tools/make-*.ps1`)

## Key features

A resident desktop gadget that shows at a glance whether something is being accessed and how much load there is.

- Display mode switching (Original / Crystal / Metalic / Info Bar)
- Display size: Compact / Full / **Task tray** (the tray icon itself becomes a disk-access LED), a mutually exclusive 3-way choice (since 3.1.1)
- CPU, MEM, SWAP (virtual memory) meters
- Disk R/W LED + speed bar, Net in/out LEDs + speed bar
- **Ping**: response-level display. A dedicated window shows the hop-by-hop route (TTL, IP, hostname, RTT) like Tracert (since 3.1.1)
- Always-on-top, tray icon, startup registration, enforce single instance
- **Reset position** from the right-click menu (recovers a main window that has drifted off-screen, since 3.1.1)
- Simple settings persistence (ini)
- **High DPI (Per-Monitor V2)**. Gadget uses 0.5-step scale; dashboard follows real DPI; Options use VCL Scaled
- **Dashboard** (separate window). Donut/history graphs for CPU / memory / SWAP / disk / network, **disk latency** (since 3.1.1), power (playback volume), Ping history, and more
- New version notice at startup (checks GitHub Latest once; disabled on the Microsoft Store build, since 3.1.1)

Crystal / Info Bar are compact-only.

## Future considerations

- Floating
- Sound
- Multiple instances / per-drive instances
- Hide on mouse approach / retreat to tray when maximized
- OwnerDraw menus
- Manual speed-range UI
- Manual language switching (ini / menu)

### What is monitored

- **Disk**: **Sum** of I/O of all physical disks (system-wide “HDD lamp” equivalent)
- **Network**: **Sum of real NICs only** (VPN, loopback, and virtual adapters are excluded where possible)
- **Ping**: Specified host (default **mg6.jp**), or auto-detect the default gateway. Interval is **at least 5 minutes**; thresholds can be changed in Options

### UI / drawing

- **Transparency**: Color-key transparency, like the old skins, to reproduce a non-rectangular window
- **Settings file**: Basically `DiskLED.ini` in the same folder as the exe (falls back to `%AppData%\DiskLED\DiskLED.ini` when that folder is not writable)
- **Meter follow**: Fast exponential rise, constant-speed fall (fps-independent). Motion is set per display mode in `layout.cfg` `[Ballistic]` (since 3.0.1)
- **Log scale**: Network speed can be linear (default) or logarithmic in Options. Disk stays auto-sense linear. CPU / MEM / SWAP stay linear
- **High DPI**: Process is **Per-Monitor V2**. The gadget uses 0.5-step scale (125% looks like 1.5×). The dashboard follows real DPI. Options use VCL Scaled
- **Privileges**: Limited to what works **without administrator** (ICMP Ping is also done as a standard user)

### Distribution and other

- **Distribution**:
  - Official distribution is the **Inno Setup installer** (`DiskLED_Setup_<version>.exe`, per-user, default `%LocalAppData%\Programs\DiskLED`)
  - A portable zip (`DiskLED-<version>-portable.zip`) is also available
- **Language**: English by default. Japanese only when the OS UI language is Japanese
- **License**: Copyright is SoRaMiMi (same as the previous version’s author). Same for `assets/`. Official packages may be used free of charge. Modification and redistribution of the source are not permitted. Help with improvements and debugging is as a co-developer (granted repository write access). Details in `LICENSE.txt`

## References

- Changelog: `public_docs/CHANGELOG.md` (Japanese) / `public_docs/EN/CHANGELOG.md` (English)
- End-user docs: `public_docs/` (Japanese) and `public_docs/EN/` (English)
- Display mode definition: `assets/LAYOUT.md`
- Build helper: `tools/build.ps1` (**Community Edition cannot compile from the command line**. IDE F9 / Shift+F9 is authoritative)
- Installer: `installer/DiskLED.iss`, `tools/make-installer.ps1` / `tools/make-portable.ps1`
