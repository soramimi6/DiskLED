# 3.3.0 以降 検討中（未確定）

3.2.0 の検討で「機能・工数のボリューム的に 3.2.0 に収まらない」と判断し次のメジャーへ送った項目。
`docs/PLANNED-3.2.0.md` と同じ方針: 実装するか・どう組み込むかは着手時に詰める。技術的な前提はここに残すが、設計・公開文には書かない。実ソースの `file:line` 引用で裏付け、推測で書かない。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|
| 1 | リソース別 TOP5 プロセス（CPU/メモリ/ディスク IO、専用ウィンドウ） | 中 | 高（プロセス列挙＋新規一覧 UI） | 1〜2週間 |
| 2 | ダッシュボード CRT/キャラクターベース表示タイプ | 高 | 中〜高（描画一式の並行実装。レンダラ抽象化の先行リファクタが要る） | 1〜2週間 |
| 3 | ダッシュボードの描画基盤を GDI+ に統一（表示内容は完全移植・見た目の変更なし） | 高（既に一部で使用中） | 中 | 3〜5日 |
| 4 | 2個目のトレイアイコン（ネット LED）のロジックを1個目と共通化（`TMainForm` の重複解消） | 高 | 中（トレイの表示・クリック・タイマーを触るため実機確認が多い） | 2〜3日 |

## 1. リソース別 TOP5 プロセス

各リソース（CPU / メモリ / ディスク IO）ごとに、そのとき最も使っているプロセス上位 5 を表示する。**ネットは対象外**（プロセス別帯域の一般権限 API が無く簡易推定に留まるため）。

### スコープ方針（着手時に詰める前提の大枠）

- **対象は CPU・メモリ・ディスク IO の 3 種**。ネットは見送り。
- **専用「プロセス」ウィンドウ**（3.1.2 新設の `TThemedHudForm`（`src/uThemedHudForm.pas`）を継承。Tracert 結果ウィンドウと同じ流儀）。ダッシュボードのセクションをその場で展開する案は採らない（下記理由）。
- **プロセスアイコンも表示する**前提（処理負荷を実測して問題があれば名前のみに落とす）。

### 検証結果（`src/dashboard/*` / `src/metrics/*` を確認）

- **プロセス列挙 API は現状ゼロ。** `psapi` は `GetPerformanceInfo`（システム全体）のみ（[uMemCollector.pas:37](../src/metrics/uMemCollector.pas#L37)）。`EnumProcesses` + `GetProcessMemoryInfo` / `QueryProcessCycleTime` / `GetProcessIoCounters` は全部新規（いずれも一般権限で可）。プロセスアイコンは `SHGetFileInfo` / `ExtractIconEx`（新規）。
- **ダッシュボードへのその場展開は重い**: `TDashboardCard` は `TCustomControl`+`Paint` の固定描画で `OnClick`・行リスト・可変高さが無い。`LayoutContent` は 5 行ハードコード（`Heights: array[0..4]`、右カラム 5 `TPaintBox` が左5行と 1:1 高さペア、[uDashboardForm.pas:404-469](../src/dashboard/uDashboardForm.pas#L404-L469)）。展開＝リフロー実装が要る。→ **別ウィンドウの方が侵襲が小さい。**
- 全プロセスの毎ティック列挙はコストが高いので、1 Hz 程度の低頻度サンプリング（`docs/DESIGN.md` 8.6 の履歴 push と同程度）にする。
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
