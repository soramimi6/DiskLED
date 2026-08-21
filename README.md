# DiskLED

Windows XP 時代に Delphi 4.0 で作られた常駐モニター（HDD / ネットワーク / CPU / メモリ）を、現代の Windows（Windows 11 など）向けに基本設計から再構築するプロジェクトです。

## 確定方針

- **開発環境**: Delphi Community Edition（個人開発・無料配布）／**VCL**・64-bit
- **対象**: Windows 10 / 11
- **見た目**: ユーザー導入の旧スキン（`.dla`）は非対応。内部は **layout.cfg ベースの表示モード**（Original / Crystal / Metalic）。`assets/<id>/layout.cfg` を足せばモード追加可能
- **画像**: 旧スキン画像を `assets/original`・`assets/crystal`・`assets/metalic` に配置（座標は各 `layout.cfg`）
- **更新頻度**: 最低 **10 fps**、デフォルト **15 fps**
- **プロセス**: **単一起動のみ**（2つ目以降は起動を抑制し、既存へフォーカス等）
- **スケール**:
  - CPU / 物理メモリ / SWAP … 0～100%
  - ディスク／ネット速度 … デバイス上限 → だめなら実測オートセンス（手動レンジは二期）
  - Ping … 応答時間を 4 段階（正常／やや遅い／遅い／タイムアウト）で表示
- **非採用（対象外）**: ユーザー向けスキン配布（`.dla`）、SSTP、**サウンド全般**、フローティング、複数起動
- **P5**: コンパクト／フル切替（ダブルクリック）と CPU／MEM／SWAP 推移グラフ（Original / Metalic）
- **P6**: ユーザー権限インストーラー（Inno Setup）＋ポータブル zip（`tools/make-*.ps1`）

## MVP（第1版）

常駐デスクトップガジェットとして「今アクセスしているか／どのくらい負荷か」が一目で分かること。

| 含める | 含めない（二期以降） |
|---|---|
| 表示モード切替（Original / Crystal / Metalic） | フローティング |
| CPU・MEM・SWAP メーター | サウンド |
| Disk R/W LED＋速度バー | 複数起動・ドライブ別インスタンス |
| Net 活動 LED＋速度バー | マウス接近で隠す／最大化でトレイ退避 |
| **Ping 表示**（両モード） | OwnerDraw メニュー |
| 最前面表示 | 高 DPI 本対応（Per-Monitor v2） |
| 設定の簡易永続化（ini） | 手動速度レンジ UI |
| トレイアイコン（起動中表示） | マウス接近で隠す／最大化でトレイ退避 |
| スタートアップ登録 | 手動言語切替（ini / メニュー） |
| 単一起動の強制 | OwnerDraw メニュー |

フル／コンパクト＋推移グラフは **P5（実装済み）**。Crystal はコンパクトのみ。

### 監視対象

- **ディスク**: 全物理ディスクの I/O を**合算**（システム全体の「HDDランプ」相当）。個別ドライブ選択は二期
- **ネットワーク**: **実 NIC のみ合算**（VPN・ループバック・仮想アダプタは除外を試みる）。特定 NIC 固定は二期
- **Ping**: 指定ホスト（既定 **mg6.jp**）、またはデフォルトゲートウェイ自動検出。間隔は **最低 5 分**、閾値はオプションで変更可

### UI・描画

- **透過**: 旧スキン同様、カラーキー透過で非矩形ウィンドウを再現する
- **Ping**: 各表示モードの枠を**描画する**（旧 cfg 座標に従う）。Original は sam2 **`Original_Base`**。フル時の `f_base`／グラフは **P5**
- **設定ファイル**: 基本は exe 横 `DiskLED.ini`。書込不可時は `%AppData%\DiskLED\DiskLED.ini`
- **メーター追従**: 軽いスムージングあり（旧リニア追尾の簡易版）。オプションで直結も二期
- **対数スケール**: 二期（初版は線形＋オートセンス）
- **高 DPI**: 初版は **100% 表示前提**（拡大時は OS 側拡大でも可）。Per-Monitor v2 の綺麗対応は二期
- **権限**: **管理者不要**で動く範囲に限定（ICMP Ping も一般権限で実施）

### 配布・その他

- **形態**: 正式配布は **Inno Setup インストーラー**（`DiskLED_Setup_3.0.0.exe`、ユーザー権限・既定 `%LocalAppData%\Programs\DiskLED`）。併せてポータブル zip（`DiskLED-3.0.0-portable.zip`）
- **パッケージ**: `tools/stage-dist.ps1` → `make-portable.ps1` / `make-installer.ps1`（先に IDE で Win64 Release ビルドが必要。CE は CLI コンパイル不可）
- **言語**: 既定は英語。OS の UI 言語が日本語のときだけ日本語（手動切替は二期）
- **名称**: 当面 **DiskLED**（バージョンは 3.x 想定）
- **ライセンス**: 後決定。旧スキン画像は原作者クレジットを明記する

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

- 表示モード定義: `assets/LAYOUT.md`
- ビルド補助: `tools/build.ps1`（**Community Edition は CLI コンパイル不可**。IDE の F9 / Shift+F9 が正）
- インストーラー: `installer/DiskLED.iss`、`tools/make-installer.ps1` / `tools/make-portable.ps1`
