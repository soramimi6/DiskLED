# DiskLED 3 — 基本設計（MVP）

確定方針は `README.md` を正とする。本書は実装用のモジュール設計・データ流・責務分割を定義する。

ユーザー向け説明は `public_docs/`（日本語）と `public_docs/EN/`（英語）を正とする。本書や実装で利用者に見える仕様を変えたら、`docs/MAINTAINING-PUBLIC-DOCS.md` に従い **両言語を同時更新** する。

## 1. 目的と非目的

### 目的

- デスクトップ常駐で、CPU／メモリ／ディスク／ネットの「今」を一目で把握する
- Ping による到達性・遅延のざっくり把握
- 旧 DiskLED のランプ／メーター感を、表示モード **Original** / **Crystal** / **Metalic** で再現する（定義は `assets/*/layout.cfg`）
- 管理者権限なし・単一起動
- 配布: **インストーラー**（Inno Setup・ユーザー権限）＋任意でポータブル zip（詳細は `public_docs/INSTALL.md` / `public_docs/EN/INSTALL.md`）

### 非目的（MVP）

- ユーザー導入のスキン配布（`.dla` / 任意 ini のオンライン配布）、サウンド、フローティング、複数起動
- 個別ディスク／NIC 選択 UI、手動レンジ UI、手動言語切替
- （**Phase5・実装済み**）コンパクト／フル切替（左ダブルクリック）と CPU／MEM／SWAP 推移グラフ。Crystal はフル定義なしでコンパクト固定

## 2. 全体アーキテクチャ

```
[WinAPI / PDH / IP Helper / ICMP]
          │
   MetricsCollector（同期・表示タイマー）
   PingCollector（低頻度・非同期）
          │  TMetricsSnapshot
   RangeEngine（速度上限）
          │
   DisplayPipeline（バリスティック・Ping段階）
          │  TDisplayState
   MainView（描画・入力）
          │
   Tray / Settings / SingleInstance
```

原則:

- **計測と描画を分離**する（Collector は UI を知らない）
- **内部スキンエンジン**: `uSkinLoader` が `assets/<id>/layout.cfg` を読み、`uDisplayModes` がフォルダを自動登録。エンドユーザー向けの `.dla` 配布はしない
- **表示タイマー 1 本**（デフォルト 15 fps ≈ 67 ms）: Collect → Range → Ballistic。スプライトコマ・LED・数字・（フル時）グラフ点が変わったときだけ Invalidate。推移グラフは正規化実測（Follow 前）を別間隔で積む（コンパクト中もバッファは更新する）
- **Ping は別タイマー／非同期**（既定・最低とも **5 分** 間隔）。UI スレッドをブロックしない

## 3. モジュール構成（Delphi VCL）

```
DiskLED/
  DiskLED.dpr
  src/
    uSingleInstance.pas
    uMainForm.pas/.dfm
    ...
    view/
      uLayoutTypes.pas
      uSkinLoader.pas       // layout.cfg → TViewLayout
      uDisplayModes.pas     // assets スキャン／登録
      uAssetStore.pas
      uMeterRenderer.pas
      uDigitRenderer.pas
    metrics/
      uPingCollector.pas
  assets/
    LAYOUT.md
    original/layout.cfg + 画像
    crystal/layout.cfg + 画像
    metalic/layout.cfg + 画像
```

新モードの追加: `assets/<id>/` に画像と `layout.cfg` を置くだけ（詳細は `assets/LAYOUT.md`）。
## 4. データモデル

### 4.1 生メトリクス `TMetricsSnapshot`

| フィールド | 単位 | 備考 |
|---|---|---|
| `CpuUsage` | 0..100 % | 全コア平均 |
| `MemUsage` | 0..100 % | 物理 |
| `SwapUsage` | 0..100 % | ページファイル相当 |
| `DiskReadBps` / `DiskWriteBps` | Byte/s | 全物理ディスク合算 |
| `DiskReadActive` / `DiskWriteActive` | bool | 閾値超で LED ON |
| `NetInBps` / `NetOutBps` | Byte/s | 実 NIC 合算 |
| `NetActive` | bool | IN または OUT で活動 |
| `PingRttMs` | ms | 成功時。失敗時は未定義 |
| `PingOk` | bool | Echo 成功か |
| `PingPending` | bool | 計測中 |
| `TickMs` | ms | サンプル間隔 |

速度の「有無」判定は、ごく小さいノイズ床（例: 数 KB/s）未満を無視する。

### 4.2 Ping 段階 `TPingLevel`

旧 DiskLED 相当の 4 段階（閾値は設定可能、初期値は旧デフォルト）:

| 段階 | 条件（既定） | 表示 |
|---|---|---|
| Normal | 0 ≤ RTT &lt; 200 ms | 緑相当 |
| Fair | 200 ≤ RTT &lt; 500 ms | 黄相当 |
| Slow | 500 ≤ RTT &lt; 1000 ms | 赤相当 |
| Timeout | 失敗または ≥ 1000 ms | 消灯／タイムアウト枠 |

### 4.3 正規化後 `TNormalizedMetrics`

- `%` 系: `Value / 100`
- 速度系: `min(1.0, Bps / RangeMaxBps)`
- Ping: 段階 enum（バリスティックしない）
- 推移グラフの履歴はこの正規化値を積む（メーター表示の追従後ではない）

### 4.4 表示状態 `TDisplayState`

- 各メーターの表示用 0..1（バリスティック後）
- LED ON/OFF
- `PingLevel`
- モード: 表示モード ID（既定 `original`）

## 5. 計測（Collectors）

いずれも **管理者不要**の API を優先。失敗時は 0 または前回値維持。

### 5.1 CPU — `uCpuCollector`

- 全体使用率: **GetSystemTimes**（全コア平均 %）
- User / Kernel 内訳: 同じ差分。Kernel は idle を除いた特権時間
- 名前・定格 MHz: レジストリ `HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0`
- 物理コア / 論理プロセッサ: `GetLogicalProcessorInformation` / `GetSystemInfo`
- 現在クロック: `CallNtPowerInformation(ProcessorInformation)`（論理 CPU の平均 MHz）

### 5.2 メモリ — `uMemCollector`

- `GlobalMemoryStatusEx`（物理・ページファイル使用率、空き）
- `GetPerformanceInfo`（キャッシュ、コミット／リミット。失敗時は 0）

### 5.3 ディスク — `uDiskCollector`

- PDH `PhysicalDisk(_Total)` の Read/Write Bytes/sec、または累積差分
- LED: Bps > ノイズ床

### 5.4 ネットワーク — `uNetCollector`

- IP Helper: 実 NIC 一覧は数秒ごとに `GetIfTable`、サンプルはキャッシュした index へ `GetIfEntry`
- リンク速度は RangeEngine へ

### 5.5 Ping — `uPingCollector`

- `IcmpCreateFile` / `IcmpSendEcho`（または `IcmpSendEcho2` 非同期）
- **UI をブロックしない**（専用スレッド、または完了コールバックでスナップショット更新）
- 間隔: **最低・既定とも 5 分（300 秒）**。これより短い間隔は設定させない（上限は必要なら後で、当面は 5 分固定でも可）
- ターゲット:
  1. 「ゲートウェイ自動」ON なら IP Helper でデフォルト GW を取得
  2. 取れなければ／自動 OFF なら設定ホスト（既定 **`mg6.jp`**）
- メニュー「Ping 更新」で即時 1 回送信
- ファイアウォールで ICMP が塞がれる環境では Timeout 表示になる（仕様として許容）

## 6. 速度レンジ — `uRangeEngine`

（従来どおり）Net はリンク速度優先、Disk はオートセンス主戦力。手動は二期。ネット正規化は直線（既定）または `Ln(1+Bps/K)/Ln(1+RangeMax/K)` の対数（K = 100 KiB/s）。オプション `SpeedScale`。ディスクは常に直線。CPU／MEM／SWAP は対象外。

## 7. 表示パイプライン — `uDisplayPipeline`

1. 正規化（`TNormalizedMetrics`）
2. 非対称バリスティック（上昇は指数、下降は定速スルーレート。経過時間ベースで fps 非依存）。プロファイル `vu` / `bar` / `peak` と Strength は `layout.cfg` の `[Ballistic]`（`assets/LAYOUT.md`）
3. LED・Ping 段階は即時
4. `TDisplayState` へ

推移グラフは正規化直後の値を、更新間隔内の **系列ごとの最大** として積む（バリスティック後ではない）。描画は `[Graph] Style` で `line`（折れ線）または `bar`（幅 1px の縦棒）。Original フルは `bar`、Metalic は `line`。ネットの `SpeedScale`（直線／対数）を切り替えたときは履歴をゼロクリアする（正規化の物差しが変わるため）。

起動約 0.9 秒は実測への線形スケールアップ（バリスティック外）。

## 8. UI／描画

### 8.1 メインウィンドウ

- ボーダーレス、最前面、カラーキー透過、ドラッグ移動、表示モード切替
- 右クリック: 登録済みモード／**Ping 更新**／オプション／終了

### 8.2 描画手順

変化があったティックのみ:

1. オフスクリーンに背景
2. メーター・LED・速度バー・**Ping パーツ**を合成
3. フル表示なら推移グラフ
4. フォームへ転送

コマ番号が同じなら GDI／カラーキー合成はスキップする。

### 8.3 レイアウト

- 定義は各 `assets/<id>/layout.cfg`（書式は `assets/LAYOUT.md`）
- Original: 旧 sam2 SkinS（`Original_Base.png` 240×34）。フルは `Original_FullBase.png` 240×52＋`[Graph]`（棒）
- Crystal: 旧 MacX SkinS（`Crystal_Base.bmp` 192×14）。フルなし
- Metalic: 旧 xsrv SkinS（`Metalic_Base.bmp` 256×24）。フルは `Metalic_FullBase.bmp` 256×48＋`[Graph]`（折れ線）
- 新モード: `assets/<id>/layout.cfg` + 画像のみ（コード変更不要）

### 8.4 トレイ／タスクバー

- **タスクトレイ**: 起動中表示用に `assets/MAINICON.ico` を表示。右クリックは本体と同じメニュー。左ダブルクリックで前面化。窓の非表示（格納）はしない
- **タスクバー**: ボタンは出さない（`WS_EX_TOOLWINDOW` / `MainFormOnTaskbar=False`）

### 8.5 オプション

- フォーム: `src/uOptionsForm.pas` + `uOptionsForm.dfm`（IDE の Form Designer でレイアウト編集可）
- 見た目: カード型パネル＋ **フォーム単位** で VCL Style `Windows10`（`styles/Windows10.vsf`）。メイン窓にはスタイルを当てない
- 起動時に `uAppStrings` でキャプションを上書き（JA/EN）
- 表示頻度（10 / 15 / 20 fps）
- グラフ更新（0.5 / 1 / 2 Hz）
- ネット速度の反応（直線／対数。ディスクはオートセンスの直線のみ）
- 常に手前、スタートアップ（Run 登録はオプション OK 時と通常終了時。終了時は現在の exe パスで付け直す）
- **Ping**: 有効／間隔／ホスト／GW 自動／段階閾値（簡易で可）

### 8.6 UI 言語

- `uAppStrings`: 起動時に `GetUserDefaultUILanguage` で判定
- 日本語 UI → 日本語、それ以外 → 英語（既定）
- メニュー・ユーザー向け例外メッセージは `S('id')` 経由。手動切替（ini）は二期

## 9. 単一起動

- 名前付き Mutex。2 つ目は既存を前面化して終了。

## 10. 設定ファイル `DiskLED.ini`

```ini
[General]
Mode=original
StayOnTop=1
Fps=15
WindowX=100
WindowY=100
Startup=0

[View]
Compact=1
GraphRateHz=1
SpeedScale=linear

[Ping]
Enabled=1
IntervalSec=300
AutoGateway=0
Host=mg6.jp
ThresholdFairMs=200
ThresholdSlowMs=500
ThresholdTimeoutMs=1000
```

保存場所: 基本は exe 横。存在しなければ／書けなければ `%AppData%\DiskLED\DiskLED.ini`（`uSettings`）。

## 11. スレッドモデル

- 表示・Disk/Net/CPU/MEM: **UI スレッド＋タイマー**（10–20 fps。見た目が変わらないときは Invalidate しない）
- Ping: **ワーカー 1 本**（送信中フラグで多重送信を抑制）
- スナップショットの Ping 欄だけワーカーが更新（必要ならクリティカルセクションで保護）

## 12. エラー耐性

- 個別 Collector 失敗でも他は継続
- Ping 失敗は Timeout 段階として表示（例外で落とさない）
- 画像欠落時はメッセージを出して終了

## 13. 実装フェーズ

| Phase | 内容 | 完了条件 |
|---|---|---|
| **Phase0** | 骨格、単一起動、背景、表示モード切替 | Original / Crystal / Metalic が表示・切替できる |
| **Phase1** | CPU/MEM/SWAP＋メーター | 実負荷でレベルが動く |
| **Phase2** | Disk/Net＋LED＋速度バー＋Range | アクセスで LED、転送でバーが振れる |
| **Phase3** | Ping（非同期・段階表示・即時更新） | 両モードで段階が変わる／メニューで即時 |
| **Phase4** | トレイ・最前面・スタートアップ・ini・オプション | MVP コア受け入れ可能 |
| **Phase5** | フル／コンパクト（ダブルクリック）＋推移グラフ、表示調整 | 旧フルモード相当＋日常利用の違和感低減 |
| **Phase6** | 紹介サイト向けインストーラー（アンインストール対応） | `public_docs/INSTALL.md` / `public_docs/EN/INSTALL.md` の手順が実物と一致 |

フェーズ完了やユーザー向け仕様の確定時は `public_docs/CHANGELOG.md` / `public_docs/EN/CHANGELOG.md` 等を更新する。

## 14. リスクと対策

| リスク | 対策 |
|---|---|
| ICMP が FW でブロック | Timeout 表示を正常系の一部とし、Host 変更を案内 |
| Ping 同期送信で UI 固まる | 必ず非同期／ワーカー |
| PDH が重い／失敗 | 累積バイト差分へフォールバック可能に |
| 仮想 NIC の常時点灯 | 除外ヒューリスティック＋実測調整 |
| 高 DPI | 3.1.0: Per-Monitor V2。ガジェットは 0.5 刻み `StretchBlt`（`GadgetScale100`）、ダッシュボードは実 DPI、オプションは VCL Scaled |

## 16. 3.1.0 追記（高 DPI・ダッシュボード）

### 高 DPI

- Win64: `AppDPIAwarenessMode=PerMonitorV2`（DPI Unaware には戻さない）
- ガジェット: `Scaled=False`。オフスクリーンは layout px、`FormPaint` で **0.5 刻み** `StretchBlt`（`GadgetScale100`。125%→1.5x。Delphi `Round` の銀行家丸めは使わない）
- ダッシュボード: `Scaled=False`。`HudMetrics(ADpi)` と自前描画が同じ `Dpi/96`
- オプション: `Scaled=True`、`PixelsPerInch=96`
- スナップ: `uWindowPlacement` が DPI 比例（`SnapPixels`）
- ダッシュボード位置・サイズは ini に **96dpi DIP** で保存（読込時に現行 Dpi で物理化。過大な旧物理値はクランプ）

### ダッシュボード

領域名は指示・実装で共通。左カラムのセクションに右カラムの詳細を挟まない。

```
DISKLED HUD（ヘッダー）
+ 左カラム
| + CPUセクション      ドーナツグラフ | 履歴グラフ
| + メモリセクション   ドーナツグラフ | 履歴グラフ
| + SWAPセクション     ドーナツグラフ | 履歴グラフ
| + ディスクセクション ドーナツグラフ | 履歴グラフ
| + ネットセクション   ドーナツグラフ | 履歴グラフ
+ 右カラム
  + CPUサブセクション      名前・コア・クロック・User/Kernel
  + メモリサブセクション   RAM / SWAP 実量とバー、空き・キャッシュ・コミット
  + 電源サブセクション     AC／バッテリ、残量、残時間
  + ディスクキュー         キュー長と IOPS
  + Ping
```

| 日本語 | 英語（コード） | 役割 |
|--------|----------------|------|
| ヘッダー | Header | タイトル・版・LIVE（`FHeaderPaint`） |
| 左カラム | Left column | 負荷の現在値と推移（`LeftColW`） |
| セクション | Section | CPU / メモリ / SWAP / ディスク / ネット（`FCards[0..4]`） |
| ドーナツグラフ | Donut | セクション左。同心円＋現在値（`MeterPaneWidth`） |
| 履歴グラフ | History graph | セクション右。直近 5 分。幅を削らない |
| 右カラム | Right column | 状態の数字・リスト（`RightColW` / `SideColWidth`） |
| サブセクション | Subsection | 右カラムの各枠 |

- `TDashboardHistory`（300 点 × 7 レーン）を MainForm が 1 Hz で push（`GraphRateHz` 非依存）
- UI: `TDashboardForm` が表示中、ドーナツは約 5 Hz（バリスティック値）、数字・履歴・右カラムは 1 Hz
- CPU パッケージ温度は一般権限 API では安定して取れないため出さない
- NIC 名一覧（`DrawNicList`）はペインタに残るが、現行レイアウトでは出さない（合算のまま）
- Ping 履歴: `TPingCollector` リング 24 件、画面は最大 5 行
- ini `[Dashboard]`: Open, WindowX/Y/W/H（DIP）。`Open=1` なら起動時に復元
- HUD ペインタ: `src/dashboard/uDashboard*.pas`（VCL Style 非使用）

## 15. 次の実装着手点

1. 3.1.1 の予定は `docs/PLANNED-3.1.1.md`。Store の登録・更新手順は `docs/Microsoft_Store.md`（いずれも公開ドキュメントには書かない）
2. MVP フェーズ Phase0–Phase6 は受け入れ済み。公開準備（配布 URL・クレジット名義など）を進める
3. 二期候補（手動レンジ、OwnerDraw メニュー等）は必要に応じて DESIGN / README の非採用・含めない表から起こす
4. アイコン変更後などは IDE で Win64 Release をビルドし、`.\tools\make-portable.ps1` / `.\tools\make-installer.ps1` で配布物を再生成する
