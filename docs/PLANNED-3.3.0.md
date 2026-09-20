# 3.3.0 以降 検討中（未確定）

3.2.0 の検討で「機能・工数のボリューム的に 3.2.0 に収まらない」と判断し次のメジャーへ送った項目。
`docs/PLANNED-3.2.0.md` と同じ方針: 実装するか・どう組み込むかは着手時に詰める。技術的な前提はここに残すが、設計・公開文には書かない。実ソースの `file:line` 引用で裏付け、推測で書かない。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|
| 1 | リソース別 TOP5 プロセス（CPU/メモリ/ディスク IO、専用ウィンドウ） | 中 | 高（プロセス列挙＋新規一覧 UI） | 1〜2週間 |
| 2 | ダッシュボード CRT/キャラクターベース表示タイプ | 高 | 中〜高（描画一式の並行実装。レンダラ抽象化の先行リファクタが要る） | 1〜2週間 |
| 3 | ダッシュボードの描画基盤を GDI+ に統一（表示内容は完全移植・見た目の変更なし） | 高（既に一部で使用中） | 中 | 3〜5日 |
| 4 | 2個目のトレイアイコン（ネット LED）のロジックを1個目と共通化（`TMainForm` の重複解消） | 高 | 中（トレイの表示・クリック・タイマーを触るため実機確認が多い） | 2〜3日 |
| 5 | PC の稼働時間（起動からの経過時間）の取得・ダッシュボード表示 | 高（`GetTickCount64` 1 本） | 低 | 0.5〜1日 |
| 6 | ディスク／ネットの累積データ量（読み書き・送受信別）の取得・ダッシュボード表示 | 高（OS の累積カウンタを直読み。実機で取得確認済み） | 低〜中（ネットは 64bit 化が要る）＋表示の設計 | 3〜4日 |
| 7 | プロセス別 CPU／メモリ消費量（絶対値・割合）の取得・ダッシュボード表示（項目1と収集層を共有） | 中〜高（PDH `Process V2` で全プロセス取得を実機確認。Win10 は未確認） | 中〜高（収集 ＋ 一覧表示の新規 UI） | 収集 2〜3日（項目1と共有）＋表示 3〜5日 |

## 1. リソース別 TOP5 プロセス

各リソース（CPU / メモリ / ディスク IO）ごとに、そのとき最も使っているプロセス上位 5 を表示する。**ネットは対象外**（プロセス別帯域の一般権限 API が無く簡易推定に留まるため）。

### スコープ方針（着手時に詰める前提の大枠）

- **対象は CPU・メモリ・ディスク IO の 3 種**。ネットは見送り。
- **専用「プロセス」ウィンドウ**（3.1.2 新設の `TThemedHudForm`（`src/uThemedHudForm.pas`）を継承。Tracert 結果ウィンドウと同じ流儀）。ダッシュボードのセクションをその場で展開する案は採らない（下記理由）。
- **プロセスアイコンも表示する**前提（処理負荷を実測して問題があれば名前のみに落とす）。

### 検証結果（`src/dashboard/*` / `src/metrics/*` を確認）

- **プロセス列挙 API は現状ゼロ。** `psapi` は `GetPerformanceInfo`（システム全体）のみ（[uMemCollector.pas:37](../src/metrics/uMemCollector.pas#L37)）。プロセスアイコンは `SHGetFileInfo` / `ExtractIconEx`（新規）。
- **取得経路は PDH `Process V2` を第一候補にする**（項目7 に実測を記載）。`OpenProcess` + `GetProcessTimes` / `GetProcessMemoryInfo` / `GetProcessIoCounters` の Win32 経路は非昇格だと約半数のプロセスしか開けず、全プロセスの TOP5 が正しく出ない。PDH は `\Process V2(*)\% Processor Time` / `Working Set - Private` / `IO Read Bytes/sec` / `IO Write Bytes/sec` が全プロセス分取れる（実機確認済み）。既存の PDH 利用（[uDiskCollector.pas:96-106](../src/metrics/uDiskCollector.pas#L96)、`uGpuCollector.pas`）と同じ作法で書ける。
- **ダッシュボードへのその場展開は重い**: `TDashboardCard` は `TCustomControl`+`Paint` の固定描画で `OnClick`・行リスト・可変高さが無い。`LayoutContent` は 5 行ハードコード（`Heights: array[0..4]`、[uDashboardForm.pas:527](../src/dashboard/uDashboardForm.pas#L527)、右カラム 5 `TPaintBox` が左5行と 1:1 高さペア、[uDashboardForm.pas:522-587](../src/dashboard/uDashboardForm.pas#L522-L587)）。展開＝リフロー実装が要る。→ **別ウィンドウの方が侵襲が小さい。**
- 全プロセスの毎ティック列挙はコストが高いので、1 Hz 程度の低頻度サンプリング（`docs/DESIGN.md` 8.6 の履歴 push と同程度）にする。
- 収集層は項目7 と共通（二重実装しない）。
- 見積り: 収集ロジック 2〜3 日、専用ウィンドウ UI（一覧描画・アイコン・ソート・更新）4〜6 日、調整・検証込みで 1〜2 週間。

## 2. ダッシュボード CRT/キャラクターベース表示タイプ

ダッシュボードに、MS-DOS 時代のキャラクターベース CRT 表示のような見た目の表示タイプを追加する。**現行ダッシュボードの見た目を再現するのではなく**、表示する情報（CPU／メモリ／SWAP／ディスク／ネットのドーナツ・推移グラフ、ディスクレイテンシ、電源、Ping 履歴など。`README.md` の「主な機能」参照）は同じまま、表現を CRT キャラクター表示のスタイルで新規に組み立てる。

- 等幅ビットマップフォントでのセル描画、疑似スキャンライン、燐光グロー、`█▓▒░` 等のブロック文字によるバー／メーター表現、点滅カーソルブロックといった要素で構成する。
- 既存のガジェットスキン機構（`layout.cfg` ベースの Original / Crystal / Metalic / Info Bar / Vintage）とは別系統。ダッシュボードは `TDashboardCard`（`TCustomControl` を継承、[uDashboardCard.pas:16](../src/dashboard/uDashboardCard.pas#L16)）が `Paint` オーバーライド（[uDashboardCard.pas:109](../src/dashboard/uDashboardCard.pas#L109)）で GDI カスタム描画しており、新しい表示タイプもここに描画ロジックを追加する形になる。
- ダッシュボードは `Scaled=False` で実 DPI 描画する設計（`docs/DESIGN.md` 15 節）なので、フォントサイズ・文字グリッドの DPI 比率計算は既存の仕組み（`Dpi/96`）をそのまま流用できる。
- **`uDashboardPainter.pas` は ~850 行・10 個の `DrawXxx` 手続きがそれぞれ直接 GDI 描画で、レンダラ差し替えの継ぎ目が無い。** CRT タイプはこれらすべてのキャラクターセル版を並行実装することになる（`DrawXxxCrt` 一式＋全呼び出し箇所で分岐、または先にレンダラ抽象化のリファクタ）。機能追加ゼロの表現追加。
- 新規に「ダッシュボード表示タイプ」という概念をどこに持たせるか（ini 設定キー、切替 UI）は要設計。既存の `[General] Mode=`（ガジェットの表示モード、[uSettings.pas:243](../src/uSettings.pas#L243)）とは別軸にする。
- 二次ウィンドウのテーマ／タイトルバー追従は 3.1.2 新設の `TThemedHudForm`（`src/uThemedHudForm.pas`）に集約済みなので、新ウィンドウを作る場合はこれを継承する。
- 見積り: 未検証。描画エンジン（フォント・スキャンライン・グロー・ブロック文字メーター）一式の新規実装が主で、既存セクション相当の情報量をキャラクター表現に落とし込む調整を含めると 1〜2 週間程度と見込むが、実機での見た目調整（フォント選定・色調・グロー強度）次第で変動する。

## 3. ダッシュボードの描画基盤を GDI+ に統一

ダッシュボードの描画（`src/dashboard/*`）を、現行の GDI ベースから GDI+ ベースの描画に差し替える。**表示内容・見た目は完全移植が前提**で、新しい表現の追加ではない（項目2の CRT 表示タイプとは別軸）。

### 現状（実ソース確認済み）

- **既に GDI+ と素の GDI が混在している。** `uDashboardGraph.pas` の推移グラフ・ドーナツグラフは `Winapi.GDIPAPI`/`Winapi.GDIPOBJ`（[uDashboardGraph.pas:40-41](../src/dashboard/uDashboardGraph.pas#L40)）を使い、`Paint` のたびに `TGPGraphics.Create(ACanvas.Handle)` でその場限りの GDI+ コンテキストを作って `SetSmoothingMode(SmoothingModeAntiAlias)`（[uDashboardGraph.pas:235,276,376,485](../src/dashboard/uDashboardGraph.pas#L235)）でアンチエイリアス描画している。
- 一方、カードのヘッダー・統計ピル・パネル本文・テキストは `uDashboardPainter.pas` の `DrawCardHeader`/`DrawStatPill`/`DrawCpuPanel` 等（[uDashboardPainter.pas:19-49](../src/dashboard/uDashboardPainter.pas#L19)）が素の VCL `TCanvas`（`FillRect`/`RoundRect`/`TextOut`、[uDashboardPainter.pas:75-113](../src/dashboard/uDashboardPainter.pas#L75)）で描いており、アンチエイリアスが効かない（角丸や斜め要素がジャギーになる）。
- **描画の単位はカード単位の独立ウィンドウ。** `TDashboardCard`（`TCustomControl` 継承、[uDashboardCard.pas:16](../src/dashboard/uDashboardCard.pas#L16)）が `DoubleBuffered := True`（[uDashboardCard.pas:76](../src/dashboard/uDashboardCard.pas#L76)）でそれぞれ独立に `Paint`（[uDashboardCard.pas:109](../src/dashboard/uDashboardCard.pas#L109)）オーバーライドしており、フォーム全体で1枚の描画サーフェスにはなっていない。
- DPI・リサイズ対応は `Dip()` ヘルパー（[uDashboardPainter.pas:68](../src/dashboard/uDashboardPainter.pas#L68)）・`THudMetrics`（`Dpi/96` 比率計算）・`ClampSizeToWorkArea`/`EffectiveMinSize`（3.2.0 項目7）に集約済みで、描画 API の差し替えとは独立したレイヤーにある。

### 方針

`uDashboardPainter.pas` の残り約10個の `DrawXxx` 手続きを、既に実績のある `TGPGraphics.Create(Canvas.Handle)` パターン（`uDashboardGraph.pas` と同じ、カードごとの `Paint` 内でその場作成）に置き換える。GDI+ は Delphi 標準ヘッダー（`Winapi.GDIPAPI`/`GDIPOBJ`）で追加ライブラリ不要、既存コードとの混在実績がある分リスクが低い。DPI・リサイズ計算（`Dip()`/`THudMetrics`）には一切手を入れず、既に計算済みの座標をそのまま渡す形にする。角丸・アンチエイリアスが全パネルで揃う副次効果はあるが、**見た目を変えないことが前提**なので既存の角丸半径・色をそのまま踏襲する。

「レンダラ抽象化」という点で項目2（CRT表示タイプ）の前提整備を兼ねられる可能性があるが、項目2は表現を丸ごと新規に作る話であるのに対し、本項目は既存の見た目を1px単位で維持したまま描画APIだけ差し替える話で、要求される検証の性質が異なる（本項目は「変わっていないこと」を確認する回帰検証が主）。

### 見積り

3〜5日（置き換え自体は機械的だが、角丸半径・フォントメトリクス・DPI換算が既存描画とピクセル単位で一致することを実機で確認する検証工数を含む）。

## 4. 2個目のトレイアイコン（ネット LED）のロジックを1個目と共通化

3.2.0 項目5（ディスクとネットの LED を同時に2つのトレイアイコンで表示）で、`uMainForm.pas` の1個目のトレイアイコン用ロジックが、2個目（`...2` 付き）としてほぼそのままコピーされている。3.2.0 の `/code-review` バッチレビューで複数の観点（簡略化・再利用）から独立に指摘された。現時点で不具合はないが、片方だけ直して食い違う恐れがある構造。

### 現状（実ソース確認済み）

- フィールド: 1個目 `FTray`／`FTrayOffIcon`／`FTrayOnIcon`／`FTrayLedOn`／`FHasTrayLedState`／`FTrayClickDelay`（[uMainForm.pas:102-105,115](../src/uMainForm.pas#L102)）に対し、2個目 `FTray2`／`FTrayOffIcon2`／`FTrayOnIcon2`／`FTrayLedOn2`／`FHasTrayLedState2`／`FTrayClickDelay2`（[uMainForm.pas:109-121](../src/uMainForm.pas#L109)）。
- 状態更新: `UpdateTrayLed`（[uMainForm.pas:1324](../src/uMainForm.pas#L1324)）と `UpdateTrayLed2`（[uMainForm.pas:1370](../src/uMainForm.pas#L1370)）は「変化なしならスキップ → On/Off アイコンを選択 → 代入 → 状態を記憶」がほぼ同じで、アイコンが無いときの扱い（1個目はアプリアイコンへ戻す、2個目は非表示のまま）だけが異なる。
- クリック処理: `TrayDblClick`／`TrayClick`／`TrayClickDelayTick`（[uMainForm.pas:1666-1687](../src/uMainForm.pas#L1666)）と `TrayDblClick2`／`TrayClick2`／`TrayClickDelayTick2`（[uMainForm.pas:1692-1712](../src/uMainForm.pas#L1692)）は、操作するタイマーが違うだけ。2つのタイマーを独立させる意図（一方のダブルクリックが他方の保留中シングルクリックを消さない、[uMainForm.pas:116-121](../src/uMainForm.pas#L116) のコメント）は保つ必要がある。

### 方針

トレイアイコン1個ぶんの状態（アイコン本体・On/Off アイコン・LED 状態・クリック用タイマー）を小さな型（レコードまたは private クラス）にまとめ、2個ぶんを配列（または2インスタンス）として持ち、`UpdateTrayLed`／クリックハンドラを「どのスロットか」を引数に取る1組のメソッドにする。1個目と2個目の差（アイコンが無いときの扱い、2個目の遅延生成 `EnsureSecondaryTray`）はスロット側の設定で吸収する。

### 実機で見ること（実装時）

- ディスク／ネットの両方を有効にした状態で、2つのトレイアイコンがそれぞれ独立して点灯・消灯すること。
- 各アイコンのシングルクリック（ダッシュボード表示）・ダブルクリック（ウィンドウ復帰）が従来どおり動き、一方の操作が他方の保留中のクリックを消さないこと。
- ディスクのみ／ネットのみ／両方を切り替えた際に、アイコンの数・表示が従来どおりであること。

## 5. PC の稼働時間（起動からの経過時間）

ダッシュボードに「稼働時間（例: 3日 4時間 12分）」を表示する。

### 検証結果（実ソース・実機確認）

- **現状、稼働時間の取得コードは無い。** 時刻源は 32bit の `GetTickCount`（[uCollector.pas:170](../src/metrics/uCollector.pas#L170) の `TickMs`、[uMetricsTypes.pas:53](../src/metrics/uMetricsTypes.pas#L53) の `Cardinal`）で、49.7 日で循環するため**流用不可**。稼働時間には 64bit の `GetTickCount64` を使う（[uStartup.pas:179](../src/uStartup.pas#L179) で既に使用実績あり）。
- 実機（Windows 11 26200・非昇格）で `GetTickCount64`・PDH `\System\System Up Time`・`Win32_OperatingSystem.LastBootUpTime` の 3 経路が一致することを確認（1.91 時間）。管理者権限は不要。
- 追加の外部依存なし。`TMetricsSnapshot`（[uMetricsTypes.pas:9](../src/metrics/uMetricsTypes.pas#L9)）へ `UptimeSec: UInt64` を足し、`TMetricsCollector.Collect`（[uCollector.pas:68](../src/metrics/uCollector.pas#L68)）で埋める。

### 表示の候補（着手時に決める）

- ダッシュボードのヘッダー右端（[uDashboardPainter.pas:165](../src/dashboard/uDashboardPainter.pas#L165) の `DrawHudHeader`。バージョンと LIVE 表示が並ぶ）に追記する案が最小変更。または電源パネル（`DrawPowerPanel`）内。
- 表記は 3.2.0 項目18（電源の残時間を単位付きにした）と揃え、文字列は `uAppStrings.pas` に JA/EN で足す（「日／時間／分」）。1 Hz の `UiTimerTick`（[uDashboardForm.pas:645](../src/dashboard/uDashboardForm.pas#L645)）で十分。

### 注意点（仕様として決めておく）

- **Fast Startup（高速スタートアップ）有効時は「シャットダウン→電源オン」で稼働時間がリセットされない**（再起動ではリセットされる）。タスクマネージャーの「稼働時間」も同じ挙動。本機は Fast Startup 無効（`HiberbootEnabled=0`）のため**この挙動は実機で再現できておらず、Microsoft の仕様説明に基づく**。「稼働時間」の定義は OS 準拠にするのが妥当（独自に補正しない）。
- スリープ中の扱い: `GetTickCount64` はスリープ中も進む。スリープを除外したい場合は `QueryUnbiasedInterruptTime` だが、目的が「起動からの経過」なら不要（本機は起動後一度もスリープしておらず両者は一致、差は未確認）。

### 見積り

0.5〜1 日（収集は数行、残りは表示位置の調整と文字列）。

## 6. ディスク／ネットの累積データ量（読み書き・送受信別）

ディスクの累積 Read／Write バイト数、ネットの累積 受信／送信バイト数をダッシュボードに表示する。既存のレート（B/s）とは別に、総量を出す。

### 検証結果（実ソース・実機確認）

- **ディスク: 累積値の取得経路は既にある。** フォールバック用の `SumDiskPerformance`（[uDiskCollector.pas:286-331](../src/metrics/uDiskCollector.pas#L286-L331)）が `\\.\PhysicalDrive0..31` を `CreateFile` の access=0 で開き、`IOCTL_DISK_PERFORMANCE` の `BytesRead`/`BytesWritten`（累積）を全ディスク分合算している。ただし通常経路は PDH のレート（[uDiskCollector.pas:142](../src/metrics/uDiskCollector.pas#L142) `Disk Read Bytes/sec`）で、累積値は使っておらず、`SumDiskPerformance` も private（[uDiskCollector.pas:51](../src/metrics/uDiskCollector.pas#L51)）。PDH には累積バイト数のカウンタが無いため、**累積値は IOCTL 経路を常用側へ引き出す**のが正確（PDH のレート×経過時間の積算は誤差が溜まるので採らない）。
- 実機（非昇格）で `PhysicalDrive0/1/2` から `BytesRead`/`BytesWritten` が取れることを確認（例: Drive0 は読み 28.8 GiB / 書き 22.3 GiB）。管理者権限は不要。存在しない番号は open 失敗で読み飛ばされる（既存コードも同じ）。
- **ネット: 既存の取得は 32bit で、そのままでは累積に使えない。** `GetIfTable`/`GetIfEntry` の `MIB_IFROW.dwInOctets`/`dwOutOctets` は `DWORD`（[uNetCollector.pas:90,96](../src/metrics/uNetCollector.pas#L90)）で、4 GiB で循環する。現行のレート算出は `DWORD` の差分で循環を吸収している（[uNetCollector.pas:504-505](../src/metrics/uNetCollector.pas#L504-L505)）が、これは差分専用の作り。累積を出すには次のいずれか:
  - (a) `GetIfTable2`/`GetIfEntry2` の `MIB_IF_ROW2`（`InOctets`/`OutOctets` が 64bit）へ移す。OS の累積値をそのまま使える。`MIB_IF_ROW2` は大きな構造体なので宣言の転記に注意（既存は `iphlpapi` を自前 `external` 宣言、[uNetCollector.pas:150-158](../src/metrics/uNetCollector.pas#L150-L158)）。
  - (b) 既存のまま差分を積算する（起動後の合計になる。DiskLED 起動前の分は出ない）。
  - 実機では 4 GiB 超のアダプターが無く、循環の実害は再現できていない（`Get-NetAdapterStatistics` の 64bit 値は最大でも 2.46 GiB）。`MIB_IFROW` の型定義からの推論。
- **合算対象は既存の「実 NIC のみ」（`IsExcludedAdapter` による除外、[uNetCollector.pas:410-426](../src/metrics/uNetCollector.pas#L410-L426)）に揃える。** Windows 設定の「データ使用量」とは一致しない（仮想アダプター・VPN を除外するため）。
- レートと同じ `TMetricsSnapshot` に `DiskReadTotal`/`DiskWriteTotal`/`NetInTotal`/`NetOutTotal`（`UInt64`）を足し、`Collect`（[uCollector.pas:112-131](../src/metrics/uCollector.pas#L112-L131)）で埋める。書式は既存の `FormatBytesGiB`（[uMetricsTypes.pas:234](../src/metrics/uMetricsTypes.pas#L234)）を流用できる（TiB 段の追加は要検討）。

### 「累積」の定義（着手時に決める・要ユーザー判断）

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| A. OS カウンタ直読み（推奨） | ディスクは IOCTL の累積、ネットは `MIB_IF_ROW2` の 64bit。実質「OS 起動後」 | DiskLED 起動前の分も出る。実装が最小。アプリを終了しても消えない | NIC の切断／再接続・無効化でカウンタが戻ることがある（合算値が減り得る）。後付けのディスク（USB 等）は接続時点から。減少は「リセット」として扱い積算側で吸収するか要検討 |
| B. DiskLED 起動後の積算 | 差分を積算 | 減少に強い | アプリ終了で 0 に戻る。起動前は出ない |
| C. 永続累計 | B を ini 等に保存し日／月でリセット | 「今月の通信量」が出せる | 保存形式・リセット規則の整理が必要（別項目に切り出す規模） |

### 表示の候補

- ディスク／ネットの各カード（`FCards[3]`/`FCards[4]`、レート表示は [uDashboardForm.pas:616-619](../src/dashboard/uDashboardForm.pas#L616-L619)）の凡例付近、またはディスクは右カラムの `DrawDiskQueue`（[uDashboardPainter.pas:520](../src/dashboard/uDashboardPainter.pas#L520)）に行を足す案。`TDashboardCard.Subtitle`（[uDashboardCard.pas:45](../src/dashboard/uDashboardCard.pas#L45)）はプロパティだけで描画されていない（未使用）ので、使うなら `Paint`（[uDashboardCard.pas:109](../src/dashboard/uDashboardCard.pas#L109)）側の描画追加が要る。
- 更新は 1 Hz で十分。ディスクの IOCTL は最大 32 回の `CreateFile` を伴うので、毎表示フレームではなく低頻度に回す。

### 見積り

収集 1〜2 日（ディスク: `SumDiskPerformance` の公開化と低頻度呼び出し 0.5 日、ネット: 64bit 化 or 積算 1 日）、表示 1〜2 日。合計 3〜4 日。

## 7. プロセス別の CPU／メモリ消費量（絶対値・割合）

各プロセスの CPU 使用率とメモリ使用量を、絶対値（%・MiB）と割合（システム全体に対する %）で取得し、主にダッシュボードで見せる。**項目1（リソース別 TOP5 プロセス）と収集層は同一**で、違いは「どこに見せるか」。収集層は 1 つだけ作り、項目1（専用ウィンドウ）と本項目（ダッシュボード）の両方から使う。

### 検証結果（実機: Windows 11 26200・非昇格で実測。Windows 10 は未確認）

- **Win32 経路（`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` ＋ `GetProcessTimes`/`GetProcessMemoryInfo`）は全プロセスを取れない。** 523 プロセス中 284（約 54%）しか開けず、残り 238 は開けなかった（サービス・別セッション・保護プロセス等）。開けたものは `GetProcessTimes`・`QueryProcessCycleTime`・`GetProcessIoCounters`・`GetProcessMemoryInfo`（`PROCESS_MEMORY_COUNTERS_EX2` の `PrivateWorkingSetSize` 含む）がすべて成功した。→ 一覧の約半数が「取得不可」になり、TOP5 にもならない。
- **PDH の `Process V2` なら全プロセスが取れる。** `\Process V2(*)\% Processor Time`・`Working Set - Private`・`Working Set`・`Private Bytes`・`IO Read Bytes/sec`・`IO Write Bytes/sec` が約 513 インスタンス分すべて有効（`PdhAddEnglishCounterW` は成功）。インスタンス名は **`名前:PID`**（例 `AdobeIPCBroker:1852`）で一意。`ID Process` カウンタは `Process V2` には無い（PID はインスタンス名から取る）。PowerShell の `Get-Counter` は無効サンプル混在で例外にするが、PDH API 直叩きでは各インスタンスの `CStatus` で個別に判定でき、問題なく取れた。
- **旧 `Process` カウンタセットはインスタンス名が一意にならない。** 本機の `\Process(*)\...` は `svchost` が同名で複数並び（511 インスタンス・重複除去後 228 名、`#1` 等の接尾辞なし）、名前をキーにした辞書だと**衝突して欠落する**。旧セットを使う場合は `ID Process` と配列添字で突き合わせる必要があり、`Process V2` が無い OS のフォールバックとしてのみ検討する。`Process V2` が Windows 10 のどの版から使えるかは**未確認**（Microsoft の資料で要確認、または Win10 実機で確認）。
- **PDH の CPU は「1 コア＝100%」**（本機で 1 コア飽和のプロセスが 100.0% を返した）。システム全体に対する割合は `÷ 論理プロセッサ数`（[uCpuCollector.pas:29](../src/metrics/uCpuCollector.pas#L29) の `Threads`）。メモリの割合は `Working Set - Private ÷ 物理メモリ総量`（`GlobalMemoryStatusEx`、[uMemCollector.pas:59](../src/metrics/uMemCollector.pas#L59)、スナップショットの `MemTotalBytes`）。タスクマネージャーのメモリ列と同じ「プライベート ワーキング セット」に相当。
- **コスト:** PDH（3 カウンタ × 約 517 インスタンス）で `PdhCollectQueryData` 約 13 ms＋配列取得 約 3 ms（定常 1 サイクル平均 約 14 ms。PowerShell 経由の単発計測なので目安）。15 fps の表示タイマー（約 66 ms 周期）で毎フレーム回す量ではない。**1 Hz 程度で収集**する（項目1の「毎ティック列挙はコストが高いので 1 Hz」とも一致）。既存の GPU 収集は同種のワイルドカード PDH を UI スレッド上で 900 ms 間隔（[uGpuCollector.pas:62](../src/metrics/uGpuCollector.pas#L62) `CSampleIntervalMs`）で回しており、プロセス別も同じ間隔で足りるが、GPU 分と合わせて 1 サイクル約 30 ms を UI スレッドに載せることになるので、**ワーカースレッド化（Ping と同じ流儀）を第一候補**とする。参考: Win32 ループは開けた 275 プロセスで約 5 ms、`Process.GetProcesses`（`NtQuerySystemInformation` 系）は約 10 ms で 511/512 プロセスのワーキングセットが取れるが、後者は非公開色の強い API で、README の「一般権限・公式 API 優先」方針（[README.md:28](../README.md#L28)）から外れるため採らない。
- 現状プロセス関連の収集コードは無い（項目1 参照）。新規ユニット（例 `uProcessCollector.pas`）を `src/metrics/` に置き、`uCollector.pas` から低頻度で呼ぶ。PDH の API 宣言は `uDiskCollector.pas`（[uDiskCollector.pas:96-106](../src/metrics/uDiskCollector.pas#L96-L106)）に個別の `external` 宣言があるが、ワイルドカードの配列取得 `PdhGetFormattedCounterArrayW` は新規に宣言が要る。GPU 使用率のワイルドカード PDH（3.2.0 項目4、`uGpuCollector.pas`）が動的インスタンス管理の先例になる。

### 表示の候補（着手時に決める）

- ダッシュボードは 5 行固定・カードは `OnClick`／行リスト／可変高さ無し（項目1 の検証結果）。**その場展開は重い**ので、まずは次のどちらか:
  1. 右カラムの CPU パネル（`DrawCpuPanel`、[uDashboardPainter.pas:230](../src/dashboard/uDashboardPainter.pas#L230)）とメモリパネル（`DrawMemAmounts`、[uDashboardPainter.pas:427](../src/dashboard/uDashboardPainter.pas#L427)）の空きに TOP3 程度を行表示する（空き領域は実機で要確認）。
  2. 項目1 の専用ウィンドウ（`TThemedHudForm` 継承）へ、絶対値・割合の両方の列を持たせる。ダッシュボードにはボタンで開く。
- 「絶対値」は CPU が `%`（1 コア基準）またはコア換算、メモリは MiB／GiB。「割合」は上記のシステム全体比。両方を並べるか切替にするかは設計時に決める。
- 同名プロセス（`chrome` 等）は合算して 1 行にするか、PID 別に出すか。名前でグルーピングすると一覧として読みやすいが、PID 別のほうが「どの 1 つか」が分かる。要判断。
- ダッシュボード以外（ガジェット本体・トレイ）へは出さない。

### 見積り

収集層 2〜3 日（項目1 と共有。二重に数えない）＋ダッシュボード表示 3〜5 日（行表示の新設・DPI 対応・ライト／ダーク・実機確認が中心）。項目1 の専用ウィンドウ案を採る場合は、UI 分は項目1 の見積りに含まれる。
