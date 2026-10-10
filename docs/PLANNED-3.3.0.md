# 3.3.0 以降 検討中（未確定）

3.2.0 の検討で「機能・工数のボリューム的に 3.2.0 に収まらない」と判断し次のメジャーへ送った項目。
`docs/PLANNED-3.2.0.md` と同じ方針: 実装するか・どう組み込むかは着手時に詰める。技術的な前提はここに残すが、設計・公開文には書かない。実ソースの `file:line` 引用で裏付け、推測で書かない。

優先順位は着手順の目安（低コスト・低リスクな独立項目を先に、範囲が広く見積りが未確定な項目を後ろに置く）。実装順はここでの並びに従うが、着手時に前後の都合で入れ替えることはある。

| # | 機能 | 対応状況 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|---|
| 1 | オプション画面のテーマ連動（ダーク／ライト）を止め、VCL 標準（Windows ネイティブ）の表示に固定 | 完了 | 高 | 低（アプリ全体スタイルの起動・切替コードの撤去が中心） | 0.5日 |
| 2 | ダッシュボードの図形描画を GDI+ に統一（テキストは GDI のまま。見た目の変更なし） | 完了 | 高（既に一部で使用中） | 中 | 3〜5日 |
| 3 | 2個目のトレイアイコン（ネット LED）のロジックを1個目と共通化（`TMainForm` の重複解消） | 完了 | 高 | 中（トレイの表示・クリック・タイマーを触るため実機確認が多い） | 2〜3日 |
| 4 | トレイアイコンの論理ドライブ別表示（C:／D: など、ドライブごとのアクセス LED） | 完了 | 高（PDH `LogicalDisk(*)` を実機確認済み） | 中〜高（収集は低〜中。台数可変のトレイアイコン管理・設定・アイコン描画が主） | 1〜1.5週間（項目3 の完了が前提） |
| 5 | PC の稼働時間（起動からの経過時間）の取得・ダッシュボード表示 | 完了 | 高（`GetTickCount64` 1 本） | 低 | 0.5〜1日 |
| 6 | ディスク／ネットの累積データ量（読み書き・送受信別）の取得・ダッシュボード表示 | 完了 | 高（OS の累積カウンタを直読み。実機で取得確認済み） | 低〜中（ネットは 64bit 化が要る）＋表示の設計 | 3〜4日 |
| 7 | リソース別 TOP5 プロセス（CPU/メモリ/I/O、ダッシュボードのプロセスページ） | 完了 | 中〜高（PDH `Process V2` で全プロセス取得を実機確認。旧 `Process` へのフォールバックは Win11 で強制して確認、Win10 実機は未確認） | 高（プロセス収集＋ページ切替＋一覧描画） | 1〜2週間 |
| 8 | プロセス別 CPU／メモリ消費量（絶対値・割合）の取得・ダッシュボード表示 | 完了（項目7で実装） | 同上 | — | 項目7に含む |
| 10 | 右クリックメニューの整理（表示モード3択・表示倍率をオプション画面へ移し、後半を並べ替え） | 完了 | 高（既存の設定・ハンドラを移すだけ。新機能なし） | 低〜中（オプション画面の配置変更と、既存ハンドラの呼び出し整理） | 1〜1.5日 |
| 11 | トレイ LED の色に黄色を追加 | 完了 | 高（生成スクリプトに色を1つ足すだけ） | 低 | 0.5日 |
| 12 | トレイ LED の色をディスクとネットで個別に指定 | 完了 | 高 | 低〜中（設定キー1つ追加と、オプション画面の色選択を表の形にする配置変更） | 1日 |
| 13 | リモートデスクトップ接続中のダッシュボードのちらつき解消 | 完了 | 高（VCL のプロパティ指定のみ） | 低 | 0.5日 |
| 14 | Ping 結果ウィンドウをダッシュボードの「Ping/経路」ページに統合（区間遅延のウォーターフォール） | 完了 | 高（ICMP は既存の `IcmpSendEcho` 系。事業者名は外部 DNS 依存。IPv6 の経路は `ipv6.google.com` で実機確認済み） | 高（経路計測の作り直し＋ページ描画＋旧ウィンドウ廃止） | 1.5〜2週間 |
| 15 | ダッシュボードのドーナツグラフ内の値の縁取りをテーマ（ライト／ダーク）に連動 | 完了 | 高（縁取り色を固定値からパレットへ） | 低 | 0.5日 |
| 16 | トレイとガジェットのネット LED を、通信が続く間も転送量の減少に合わせて一瞬消灯させる（ハブのアクセスランプ風） | 完了 | 高（毎フレームの転送量は既に取得済み） | 低 | 0.5日 |
| 17 | 画面表示の用語・表記の統一（トレイのツールチップの「読み／書き」ほか） | 完了 | 高（文字列表の書き換えのみ） | 低 | 0.5日 |
| 18 | ネット速度の表示単位をバイト（KB/s）からビット（Kbps、1000 区切り）へ変更 | 完了 | 高（表示関数の追加と呼び出し 2 か所の差し替え） | 低 | 0.5日 |
| 19 | 計測値をタスクマネージャー等と揃える（ネットの重複計上、CPU 使用率・クロック、SWAP、スタンバイ、ディスク詳細・プロセス CPU の算出） | 完了 | 高（すべて一般権限の公式 API。この PC で値を照合済み） | 中（収集ユニット 6 本の修正） | 1.5日 |

**優先順位の理由:**
- **1**（0.5日）: 低コスト・低リスクで他項目に依存しない単独修正。先に片付けて着手障壁を減らす。
- **2**（3〜5日）: 見た目を変えない内部リファクタ。単独の利用者価値はないが、描画を GDI+ に揃えて以降のダッシュボード改修の土台にする。
- **3**（2〜3日）: 新機能ではないが `/code-review` バッチレビューで複数回指摘された重複構造の解消（技術的負債）。他項目と独立。項目4 の土台にもなる。
- **4**（1〜1.5週間）: 項目3（トレイアイコン1個ぶんの状態を型にまとめる共通化）を土台にして「N 個の可変スロット」へ広げる形になるため、項目3 の後でないと着手できない。
- **5**（0.5〜1日）: 低コスト・低リスクで他項目に依存しない単独の新機能。
- **6**（3〜4日）: 独立した新機能。ただし「累積」の定義（A/B/C案）はユーザー判断が要るため着手前に確定させる。
- **7・8**（1〜2週間）: 項目8 の表示は項目7 のプロセスページに含めて一度に作る。範囲が大きく実機検証（Win10 での `Process V2` 対応含む）が要るため、単独の低コスト項目より後。
- **10**（1〜1.5日）: 既存機能の配置換えのみで他項目に依存しない。項目1 と同じ `uOptionsForm.dfm` を触るため、**項目1 の直後に続けて着手**するとオプション画面の実機確認を一度にまとめられる（番号は後付けの 10）。
- **11・12**（計 1.5日）: どちらもオプション画面の「トレイ LED の色」カードを触るので、**11 → 12 の順に続けて着手**し、カードの配置変更と実機確認を一度にまとめる。他項目とは独立（番号は後付け）。
- **13**（0.5日）: 他項目と独立した小さな修正。項目7 がダッシュボードのフォームを触っているため、**項目7 の完了後**に着手して衝突を避ける（番号は後付け）。
- **14**（1.5〜2週間）: 項目7 のページ切替・タブ行・周期選択の仕組みの上に作るため、項目7 の後（番号は後付け）。
- **15**（0.5日）: 見た目だけの小さな修正で他項目と独立。項目14 と同じ `uDashboardForm.pas` は触らないため、いつ入れてもよい（番号は後付け）。
- **16**（0.5日）: トレイ LED の点灯判定だけの小さな修正で他項目と独立（番号は後付け）。
- **17**（0.5日）: 文字列表（`uAppStrings.pas`）だけの修正で他項目と独立（番号は後付け）。
- **18**（0.5日）: 表示の整形だけの小さな修正で他項目と独立（番号は後付け）。
- **19**（1.5日）: 項目18 の実機確認で見つかった計測の誤りの修正。表示の値そのものが変わるため、項目18 の直後に続けて実機確認する（番号は後付け）。

## 1. オプション画面のテーマ連動を止め、VCL 標準の表示に固定（完了）

オプション画面（`TOptionsForm`）は OS のダーク／ライト設定に連動して VCL スタイル（`Windows10` / `Windows10 Dark`）で描画されているが、これをやめ、常に VCL 標準（Windows ネイティブのコントロール描画）で表示する。ダッシュボード・Ping/Tracert 結果窓・ガジェット本体（`TThemedHudForm` 系・`TMainForm`）のテーマ追従は対象外（変更しない）。

### 現状（実ソース確認済み）

- 連動の仕組みは**アプリ全体の VCL スタイル**。`ApplyAppStyle`（[uAppStyle.pas:115](../src/uAppStyle.pas#L115)）が `SystemUsesLightTheme` でライト／ダークの `.vsf` を選び `TStyleManager.TrySetStyle`（[uAppStyle.pas:154](../src/uAppStyle.pas#L154)）で適用する。起動時に [DiskLED.dpr:69](../DiskLED.dpr#L69) で1回、OS のライト／ダーク切替時に `TMainForm.WMSettingChange`（[uMainForm.pas:1812-1827](../src/uMainForm.pas#L1812)）から再適用される。
- `TOptionsForm` は自前の `StyleName` を持たず、このアプリ全体スタイルを継承している（[uOptionsForm.pas:134-140](../src/uOptionsForm.pas#L134)）。他のウィンドウは `StyleName := 'Windows'` で除外済み（[uThemedHudForm.pas:49](../src/uThemedHudForm.pas#L49)、[uMainForm.pas:332](../src/uMainForm.pas#L332)）なので、**アプリ全体スタイルの実質的な利用者は Options のみ**。
- タイトルバーのダーク化は別経路で、`TOptionsForm.FormCreate` が `ApplyHudTitleBar(Handle)`（[uOptionsForm.pas:141](../src/uOptionsForm.pas#L141)、実体は [uDashboardTheme.pas:112-126](../src/dashboard/uDashboardTheme.pas#L112)）を呼んでいる。

### 方針

- **アプリ全体スタイルを廃止する**: `ApplyAppStyle` の呼び出し（[DiskLED.dpr:65-69](../DiskLED.dpr#L65)）、`WMSettingChange` 内の再適用（[uMainForm.pas:1812-1827](../src/uMainForm.pas#L1812)）、`uAppStyle.pas` 自体（＋ `uses` の `uAppStyle`、[uMainForm.pas:234](../src/uMainForm.pas#L234)）を撤去する。`Vcl.Styles`/`Vcl.Themes` のリンクも外れる。
- Options は何もせずネイティブ描画になる。`TOptionsForm.FormCreate` の `ApplyHudTitleBar(Handle)` も外し、**タイトルバーもライト固定**にする（本文だけ標準でタイトルバーだけダークになる不整合を避ける）。
- `TThemedHudForm`／`TMainForm` の `StyleName := 'Windows'` はアプリ全体スタイルが無くなれば不要になるが、無害なので残すか外すかは実装時に決める（外す場合は [uThemedHudForm.pas:44-49](../src/uThemedHudForm.pas#L44) のコメントも整理する）。
- `styles/*.vsf` は不要になる。同梱処理（[tools/stage-dist.ps1:15,68-70](../tools/stage-dist.ps1#L15)、[tools/make-msix-sideload.ps1:69](../tools/make-msix-sideload.ps1#L69)）から外す。
- 公開文書の更新: `docs/DESIGN.md:207`（VCL Style `Windows10` を使う旨の記述）を実装に合わせて直す。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- OS をダークにした状態でオプション画面を開いても、本文・タイトルバーとも標準（ライト）の見た目であること（125/150/200% DPI で崩れないこと）。
- オプション画面を開いたまま OS のライト／ダークを切り替えても、Options が変化しないこと。ダッシュボード・結果窓・ガジェットは従来どおり追従すること。
- `.dfm` 上のコントロール（タブ・チェック・ボタン・アセットエディタ部）が、スタイル無しでレイアウト崩れ・文字切れを起こしていないこと（これまで `Windows10` スタイル前提で寸法を調整していた可能性がある）。

### 見積り

0.5日（コード撤去は小さい。実機確認が中心）。

## 2. ダッシュボードの図形描画を GDI+ に統一（完了）

ダッシュボードの図形描画（`src/dashboard/*`）を、現行の GDI ベースから GDI+ ベースの描画に差し替える。**表示内容・見た目は完全移植が前提**で、新しい表現の追加ではない。

**テキストは対象外（GDI の `TextOut` のまま）。** GDI+ の `DrawString` は GDI と文字幅・字送りの計測が異なり、`TextWidth`/`TextHeight` に基づく既存のレイアウト計算（右寄せ・`Ellipsize`、[uDashboardPainter.pas:200-211](../src/dashboard/uDashboardPainter.pas#L200)）とずれるため「見た目の変更なし」を守れない。GDI の `TextOut` は ClearType で既にアンチエイリアスされており、GDI+ 化による画質上の利点も無い。

図形は角丸矩形・矩形塗りつぶし（`GpFillRoundRect`/`GpStrokeRoundRect`/`GpFillRect`、[uDashboardGraph.pas:101-202](../src/dashboard/uDashboardGraph.pas#L101)）に集約済み。GDI の図形描画が残るのは、GDI+ の起動に失敗したときのフォールバック経路（`DrawLineGdiFallback`/`DrawConcentricMeterFallback` と `Gp*` 内の分岐）のみ。

### 現状（実ソース確認済み）

- **既に GDI+ と素の GDI が混在している。** `uDashboardGraph.pas` の推移グラフ・ドーナツグラフは `Winapi.GDIPAPI`/`Winapi.GDIPOBJ`（[uDashboardGraph.pas:40-41](../src/dashboard/uDashboardGraph.pas#L40)）を使い、`Paint` のたびに `TGPGraphics.Create(ACanvas.Handle)` でその場限りの GDI+ コンテキストを作って `SetSmoothingMode(SmoothingModeAntiAlias)`（[uDashboardGraph.pas:235,276,376,485](../src/dashboard/uDashboardGraph.pas#L235)）でアンチエイリアス描画している。
- 一方、カードのヘッダー・統計ピル・パネル本文・テキストは `uDashboardPainter.pas` の `DrawCardHeader`/`DrawStatPill`/`DrawCpuPanel` 等（[uDashboardPainter.pas:19-49](../src/dashboard/uDashboardPainter.pas#L19)）が素の VCL `TCanvas`（`FillRect`/`RoundRect`/`TextOut`、[uDashboardPainter.pas:75-113](../src/dashboard/uDashboardPainter.pas#L75)）で描いており、アンチエイリアスが効かない（角丸や斜め要素がジャギーになる）。
- **描画の単位はカード単位の独立ウィンドウ。** `TDashboardCard`（`TCustomControl` 継承、[uDashboardCard.pas:16](../src/dashboard/uDashboardCard.pas#L16)）が `DoubleBuffered := True`（[uDashboardCard.pas:76](../src/dashboard/uDashboardCard.pas#L76)）でそれぞれ独立に `Paint`（[uDashboardCard.pas:109](../src/dashboard/uDashboardCard.pas#L109)）オーバーライドしており、フォーム全体で1枚の描画サーフェスにはなっていない。
- DPI・リサイズ対応は `Dip()` ヘルパー（[uDashboardPainter.pas:68](../src/dashboard/uDashboardPainter.pas#L68)）・`THudMetrics`（`Dpi/96` 比率計算）・`ClampSizeToWorkArea`/`EffectiveMinSize`（3.2.0 項目7）に集約済みで、描画 API の差し替えとは独立したレイヤーにある。

### 方針

`uDashboardPainter.pas`・`uDashboardCard.pas`・`uDashboardGraph.pas` の図形描画を、既に実績のある `TGPGraphics.Create(Canvas.Handle)` パターン（`uDashboardGraph.pas` と同じ、カードごとの `Paint` 内でその場作成）に置き換える。GDI+ は Delphi 標準ヘッダー（`Winapi.GDIPAPI`/`GDIPOBJ`）で追加ライブラリ不要、既存コードとの混在実績がある分リスクが低い。DPI・リサイズ計算（`Dip()`/`THudMetrics`）には一切手を入れず、既に計算済みの座標をそのまま渡す形にする。角丸・アンチエイリアスが全パネルで揃う副次効果はあるが、**見た目を変えないことが前提**なので既存の角丸半径・色をそのまま踏襲する。

### 見積り

3〜5日（置き換え自体は機械的だが、角丸半径・フォントメトリクス・DPI換算が既存描画とピクセル単位で一致することを実機で確認する検証工数を含む）。

## 3. 2個目のトレイアイコン（ネット LED）のロジックを1個目と共通化（完了）

3.2.0 項目5（ディスクとネットの LED を同時に2つのトレイアイコンで表示）で、`uMainForm.pas` の1個目のトレイアイコン用ロジックが、2個目（`...2` 付き）としてほぼそのままコピーされている。3.2.0 の `/code-review` バッチレビューで複数の観点（簡略化・再利用）から独立に指摘された。現時点で不具合はないが、片方だけ直して食い違う恐れがある構造。

### 現状（実ソース確認済み）

- フィールド: 1個目 `FTray`／`FTrayOffIcon`／`FTrayOnIcon`／`FTrayLedOn`／`FHasTrayLedState`／`FTrayClickDelay`（[uMainForm.pas:102-105,115](../src/uMainForm.pas#L102)）に対し、2個目 `FTray2`／`FTrayOffIcon2`／`FTrayOnIcon2`／`FTrayLedOn2`／`FHasTrayLedState2`／`FTrayClickDelay2`（[uMainForm.pas:109-121](../src/uMainForm.pas#L109)）。
- 状態更新: `UpdateTrayLed`（[uMainForm.pas:1335](../src/uMainForm.pas#L1335)）と `UpdateTrayLed2`（[uMainForm.pas:1381](../src/uMainForm.pas#L1381)）は「変化なしならスキップ → On/Off アイコンを選択 → 代入 → 状態を記憶」がほぼ同じで、アイコンが無いときの扱い（1個目はアプリアイコンへ戻す、2個目は非表示のまま）だけが異なる。
- クリック処理: `TrayDblClick`／`TrayClick`／`TrayClickDelayTick`（[uMainForm.pas:1677-1698](../src/uMainForm.pas#L1677)）と `TrayDblClick2`／`TrayClick2`／`TrayClickDelayTick2`（[uMainForm.pas:1703-1722](../src/uMainForm.pas#L1703)）は、操作するタイマーが違うだけ。2つのタイマーを独立させる意図（一方のダブルクリックが他方の保留中シングルクリックを消さない、[uMainForm.pas:116-121](../src/uMainForm.pas#L116) のコメント）は保つ必要がある。

### 方針

トレイアイコン1個ぶんの状態（アイコン本体・On/Off アイコン・LED 状態・クリック用タイマー）を小さな型（レコードまたは private クラス）にまとめ、2個ぶんを配列（または2インスタンス）として持ち、`UpdateTrayLed`／クリックハンドラを「どのスロットか」を引数に取る1組のメソッドにする。1個目と2個目の差（アイコンが無いときの扱い、2個目の遅延生成 `EnsureSecondaryTray`）はスロット側の設定で吸収する。

### 実機で見ること（実装時）

- ディスク／ネットの両方を有効にした状態で、2つのトレイアイコンがそれぞれ独立して点灯・消灯すること。
- 各アイコンのシングルクリック（ダッシュボード表示）・ダブルクリック（ウィンドウ復帰）が従来どおり動き、一方の操作が他方の保留中のクリックを消さないこと。
- ディスクのみ／ネットのみ／両方を切り替えた際に、アイコンの数・表示が従来どおりであること。

## 4. トレイアイコンの論理ドライブ別表示（完了）

トレイの LED を、現行の「全ディスク合算（1 個）」に加えて、論理ドライブ（C:／D: …）ごとのアクセス LED として出せるようにする。物理ドライブ別（`\\.\PhysicalDriveN` 単位）ではなく論理ドライブ別を採る前提で、両者の差を下記に記録する。

### 現状（実ソース確認済み）

- ディスクの測定は**全ディスク合算のみ**。PDH は `PhysicalDisk(_Total)` 固定（[uDiskCollector.pas:142-164](../src/metrics/uDiskCollector.pas#L142)）、IOCTL フォールバックも `\\.\PhysicalDrive0..31` を全部足して 1 値にしている（[uDiskCollector.pas:302-320](../src/metrics/uDiskCollector.pas#L302)）。ドライブごとの値・一覧は持っていない。
- 点灯判定は `TDisplayPipeline.Update` で合算値から `DiskRWOn` を 1 つだけ作る（[uDisplayPipeline.pas:279-281](../src/metrics/uDisplayPipeline.pas#L279)）。トレイは 2 個固定（1個目＝ディスクまたはネット、2個目＝ネット。[uMainForm.pas:1157-1161](../src/uMainForm.pas#L1157)、`TrayLedSourceOn` は [uMainForm.pas:1264-1273](../src/uMainForm.pas#L1264)）。**N 個の可変個数を扱う構造は無い**（項目3 の共通化後も「固定2スロット」が前提）。
- デバイス着脱の検知コード（`WM_DEVICECHANGE` 等）はリポジトリに無い。動的追従の先例は「ネットのアダプター一覧を数秒ごとに `GetIfTable` で再取得」（[uNetCollector.pas:3-4](../src/metrics/uNetCollector.pas#L3)）と、GPU の PDH ワイルドカード配列取得（`PdhGetFormattedCounterArrayW`、[uGpuCollector.pas:216-226](../src/metrics/uGpuCollector.pas#L216)）。

### 物理ドライブ別と論理ドライブ別の違い

| 観点 | 物理（`PhysicalDriveN`／`PhysicalDisk(N …)`） | 論理（ドライブレター／`LogicalDisk(C:)`） |
|---|---|---|
| 測定 | 既存の IOCTL 経路（access=0 で open → `IOCTL_DISK_PERFORMANCE`）がそのまま使える。PDH も同じ作法の `PhysicalDisk(*)` | PDH `LogicalDisk(*)` が第一候補（実機で `C:`／`D:`／`E:`／`HarddiskVolumeN`／`_Total` を確認）。IOCTL は `\\.\C:` のボリュームハンドルで可能だが未検証 |
| 対応関係 | 1 台＝1 LED で単純 | ドライブレター ↔ ボリューム ↔ パーティション ↔ 物理ディスクが **N:M**。1 台に複数パーティションなら物理は 1 個・論理は複数。複数ディスクにまたがるボリューム（記憶域スペース・ダイナミックディスク）は 1 レターが複数台。レター無しのボリューム（EFI・回復）は出ない |
| 一覧の取り方 | 番号 0..31 を毎回 open して探す（既存方式。着脱検知の仕組みは無い） | **`GetLogicalDrives` + `GetDriveType` は使えない**。実機で C:/D:/E: 以外に G:／M:（`subst`）／X: が `Fixed` として見えるが `LogicalDisk` インスタンスは無い。PDH のインスタンス名（`X:` 形式のみ採用）が実体を反映する |
| 着脱への追従 | 番号は再起動・再接続で入れ替わる（USB を挿す順で `PhysicalDrive2` が別のディスクになる）。設定に持つキーが不安定（シリアル等が要る） | レターは利用者が見て分かる安定したキー。追加・削除・レター変更は PDH のインスタンス一覧の再列挙（数秒ごと）で拾える。ただし空のカードリーダー／光学ドライブ（レターはあるがメディア無し）・BitLocker ロック中・ネットワークドライブ・`subst` の扱いを決める必要がある |
| 副作用の懸念 | 既存コードが毎サンプル open→close しており実績あり | ボリュームハンドルを**保持し続けると**エクスプローラーの安全な取り外しの妨げになる可能性がある（未検証。要実機確認）。PDH 経由ならハンドル保持が発生しないので、PDH 第一候補とする理由の一つ |
| 値の意味 | ディスク実 I/O | 論理側は VSS 差分領域などパーティション外の I/O を含まない（物理と合算値が一致しない）。LED の意味づけ（「そのドライブが触られている」）は論理のほうが利用者に直感的 |

**収集層の難易度は両者でほぼ同程度**（どちらも「一覧を取る → インスタンスごとにレートを取る」で、GPU 収集が先例）。**差が出るのは追従の設計**: 物理は不安定な番号を設定キーにする難しさ、論理はレターの実体判定（上記の除外規則）の難しさ。論理のほうが利用者向けの説明・設定が単純で、総じて論理のほうが実装しやすい。

### 実装上の主なコスト（論理・物理に共通、収集より大きい）

- **トレイアイコンが可変個数になる。** 現行は 2 個固定の `FTray`／`FTray2`。ドライブごとに `TTrayIcon` を生成・破棄する管理が要る（Windows 11 は新しいトレイアイコンを既定でオーバーフローに入れるため、利用者は個別にピン留めが要る点も説明が要る）。
- **個別 LED の状態を持つ場所が無い。** `TMetricsSnapshot`／`TDisplayPipeline` はディスクを 1 系統しか持たない。ドライブ別のレート・点灯判定（`IsActiveBps` 相当）・点灯の最小維持時間などを配列で持たせる拡張が要る。
- **アイコンにドライブ名が要る。** どのアイコンがどのドライブか分からないため、16px（高 DPI で 32px）の LED アイコンにレター（`C` 等）を載せるか、ツールチップだけで識別するかを決める必要がある。既存の On/Off アイコンは固定アセット（アセットエディタ）由来なので、レター合成は新規描画になる。
- **設定と UI。** 「どのドライブをトレイに出すか」の選択（ini キーはレターを保持。存在しないレターの扱い）と、オプション画面の一覧。着脱で一覧が変わるので開いている間の更新も要る。

### 決定事項

- 対象ドライブ: 固定・リムーバブル（USB）。PDH `LogicalDisk` の `X:` 形式インスタンスを対象とし、`_Total` と `HarddiskVolumeN` は除外する。サブスト・ネットワークドライブは PDH に現れないため対象外。光学ドライブは OS 制約により非対応（PDH・`IOCTL_DISK_PERFORMANCE` のいずれも活動値を返さない）。オプションの一覧には「（非対応）」として種類付きで表示し、選択不可とする。
- ツールチップ: ドライブ別・状況表示とも値は直近 1 秒の平均。瞬間値では点滅するアイコンに対して大半が 0 になるため。
- 識別: ツールチップ（`DiskLED C:`）に加え、アイコン右下に英字 1 文字（コロン無し）を小さく重ねる。文字は点灯状態によらず固定で、点灯・消灯はアイコン自身が表す。文字の大きさ・フォントは実機で調整した（`uTrayIconComposer.pas`）。3〜4 文字の重ね表示（`NET` / `DISK`）は文字がアイコンに重なりすぎるため採用しない。ネット用アイコンのツールチップは「ネットアクセス」。
- 合算 LED: 設定 `[Tray] LedTotal`（既定 ON）が ON なら、ドライブ別を選んでも合算 LED を出し続ける。OFF のときは、ドライブ別が 1 つ以上選択されている間は合算 LED をトレイに出さない。ドライブ別が未選択なら従来どおり合算 LED のみ。既定を ON にするのは、3.3.0 より前の版は合算 LED だけを出しており、旧版の ini（`LedTotal` キーが無い）から更新しても合算 LED が消えないようにするため。
- 同時表示上限: 暫定 16 個。定数で持ち、実機で調整する。
- 設定キー: `[Tray] LedDrives=C:,D:`（既定は空＝従来どおり）、`[Tray] LedTotal`。存在しないドライブ文字も保持し、接続された時点で表示する。
- 段階（すべて完了）: (a) 収集・パイプライン → (b) ドライブ別トレイ（着脱追従） → (c) 設定キーとオプション画面のチェックリスト。

### 実機で見ること（実装時）

- USB ディスクの接続・取り外し・「安全な取り外し」で、アイコンの増減と取り外しの成否（DiskLED がハンドルを掴んでいて取り外しが拒否されないこと）。
- 1 台に複数パーティション（C:／D: が同一ディスク）で、論理は個別に点灯し、合算は `LedTotal` ON のときだけ従来どおり点灯すること。
- `LedTotal` が ON（既定）なら、`LedDrives` を選んでも合算アイコンがトレイに残ること。OFF にすると合算アイコンが消え、ON に戻すと再び現れること。
- 上限 16 個まで増やしたとき、トレイの見た目・オーバーフローの扱いに問題がないこと。
- ツールチップに対象ドライブ名（文字）と点灯状態が出ること。

### 見積り

収集 1〜2 日（PDH `LogicalDisk(*)` のワイルドカード列挙・定期再列挙・ドライブ別レート）、点灯判定・パイプライン拡張 1〜2 日、トレイの可変個数管理（項目3 の土台の上）2〜3 日、設定・オプション UI 1〜2 日。合計 1〜1.5 週間。物理ドライブ別にする場合も収集は同程度で、設定キー（シリアル等の安定識別子）の設計が加わる分、大差は付かない。
## 5. PC の稼働時間（起動からの経過時間）（完了）

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

## 6. ディスク／ネットの累積データ量（読み書き・送受信別）（完了）

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

## 7. リソース別 TOP5 プロセス（ダッシュボードのプロセスページ）（完了）

各リソース（CPU / メモリ / I/O）ごとに、そのとき最も使っているプロセス上位 5 を表示する。**ネット帯域の段は作らない**（プロセス別帯域の一般権限 API が無く簡易推定に留まるため）。項目8（プロセス別の絶対値・割合）の表示もこのページで行う。

### 決定事項

- **表示場所は別ウィンドウではなく、ダッシュボード内のページ。** ヘッダー直下にタブ行（「概要」「プロセス」）を置き、クリックで本体の表示を切り替える。オプション画面のタブと同じ使い方。概要ページは現行のセクション×5＋サブセクション×5 で、変更しない。
- **同名プロセスは名前で合算して 1 行**（例 `chrome (12)`）。順位は合算値で決める。
- **配置は横に 3 列**（左から CPU → メモリ → I/O）、各列は縦長のリスト。件数は既定の大きさ（960×720 DIP）以下で 5 件、高さが約 90 DIP 増えるごとに 1 件ずつ増やす（最大 20 件）。1 件の高さをほぼ一定に保ち、広げても間延びさせない。
- **1 件は 4 行で、目的（負荷をかけているプロセスの特定・調査）に効く順に上から並べる。**
  - 1 行目: アイコン｜名前（件数）｜値
  - 2 行目（何か）: メインウィンドウのタイトル。無ければ説明（`FileDescription`）、それも無ければ製品名（`ProductName`）。後ろに会社名（`CompanyName`）。
  - 3 行目（状態）: 実行ユーザー名（昇格していれば「管理者」）・コミットサイズ（`Private Bytes`）・ハンドル数・スレッド数。
  - 4 行目（どこ）: 実行ファイルのパス。1 件の高さが 4 行に足りないとき（最小サイズ付近）は省く。
  - ツールチップ（件の上にマウスを乗せる）: 上記すべてに、バージョン（`FileVersion`）・64bit／32bit・著作権（`LegalCopyright`）を加える。見た目と表示までの待ち時間はガジェット本体のツールチップ（`uHoverTip.pas` の `THoverTip`、ネイティブのツールチップ）に揃える。VCL の `ShowHint` は、`Scaled := False` のダッシュボードでは 96 DPI 相当の小さい文字になるため使わない。
  - 仮想メモリ量は 64bit では判断材料にならないため出さない。
- **取れないときの扱い。** ユーザー名・昇格・64bit／32bit・パスと実行ファイル由来の情報は、プロセスを開ける場合だけ（非昇格で約半数、項目8）。開けないときは 2 行目に「詳細を取得できません」と出す。ウィンドウタイトル・コミット・ハンドル・スレッドは全プロセスで取れる。
- **同名で合算した行**は、コミット・ハンドル・スレッドを合計し、ウィンドウタイトルは合算したプロセスのうち最初に見つかったもの、それ以外は代表 PID のものを出す。
- **更新周期は 3／5／10 秒から選ぶ**（既定 3 秒）。1 秒では読み取る前に値が変わるため。切替はプロセスページ表示中だけタブ行の右端に出す。選んだ周期は `[Dashboard] ProcessIntervalSec` に保存する。値は周期の間の平均（PDH のレート系カウンタは 2 回の収集の間の平均を返す）。
- **更新周期の選択肢の最後に「停止」を置く。** 選ぶとその時点のリストのまま止め（収集も止める）、周期を選び直すと再開する。停止は保存しない。概要ページへ移るかダッシュボードを閉じると解除する（リストは破棄されるため、止めたまま空のリストを出さない）。
- **列の見出しは並び順を表す。** 「CPU使用率の高い順」「メモリ使用量の多い順」「I/O量の多い順」（英語は `By CPU usage`／`By memory used`／`By I/O (read + write)`）。メモリは使用量（プライベート ワーキング セット）で並べ、割合は同じ値を物理メモリ総量で割ったものなので「占有率」とは書かない。
- **3 列目は「ディスク」ではなく「I/O」と呼ぶ。** 値は PDH の `IO Read Bytes/sec`・`IO Write Bytes/sec` で、ファイル・ネットワーク・デバイスの全 I/O を数える（ディスクだけの値ではない）ため「ディスク」とは呼ばない。タスクマネージャーの「ディスク」列とは一致しない。
- **I/O は読み＋書きの合計 B/s で順位を決め**、行には読み・書きを別々に出す。
- プロセスアイコンを表示する。
- **旧 `\Process(*)` へフォールバックした OS では、全行を既定のアプリアイコンにする**（PID の突き合わせをしない）。

### 現状（実ソース確認済み）

- **ダッシュボードにページの概念は無い。** 本体はヘッダー `FHeaderPaint`（`alTop`、[uDashboardForm.pas:137-141](../src/dashboard/uDashboardForm.pas#L137)）・左カラム `FCards[0..4]`・右カラムの `TPaintBox` 5 個で、`LayoutContent`（[uDashboardForm.pas:522-587](../src/dashboard/uDashboardForm.pas#L522)）が固定配置する。クリック処理（`OnClick`/`OnMouseDown`）はどこにも無い。
- 更新は表示中だけ動く 2 本のタイマー: 1 Hz の `UiTimerTick` → `RefreshData`（[uDashboardForm.pas:604-649](../src/dashboard/uDashboardForm.pas#L604)）と、約 5 Hz の `MeterTimerTick`（ドーナツ、[uDashboardForm.pas:632-643](../src/dashboard/uDashboardForm.pas#L632)）。`FormShow`/`FormHide` で有効・無効を切り替える（[uDashboardForm.pas:734-753](../src/dashboard/uDashboardForm.pas#L734)）。履歴グラフ用の 1 Hz push は MainForm 側で、ダッシュボードの表示状態とは独立（`docs/DESIGN.md:330`）。
- 最小サイズは 800×600 DIP が下限（`EffectiveMinSize`、[uDashboardForm.pas:273-292](../src/dashboard/uDashboardForm.pas#L273)）。
- VCL の `TTabControl`/`TPageControl` はネイティブ描画で、ダッシュボードの HUD 配色（`HudPalette`、ライト／ダーク追従）に合わない。→ タブ行は自前描画にする。
- **プロセス関連の収集コードは無い。** `psapi` は `GetPerformanceInfo`（システム全体）のみ（[uMemCollector.pas:37](../src/metrics/uMemCollector.pas#L37)）。取得経路は PDH `Process V2`（全プロセスが非昇格で取れる。実測は項目8）。
- PDH ワイルドカード配列取得の先例は `uGpuCollector.pas`（API 宣言 [uGpuCollector.pas:93-105](../src/metrics/uGpuCollector.pas#L93)、失敗時の再初期化 `SuspendPdh` [uGpuCollector.pas:173-181](../src/metrics/uGpuCollector.pas#L173)）と `uDriveCollector.pas`（[uDriveCollector.pas:61-73](../src/metrics/uDriveCollector.pas#L61)）。PDH の `external` 宣言はユニットごとに個別に持つ流儀。
- ワーカースレッドの先例は `TPingCollector`（`TThread` 派生＋`TCriticalSection`＋`TEvent`、[uPingCollector.pas:102-167](../src/metrics/uPingCollector.pas#L102)）。結果は `CopyPingHistory` のようにロック付きでコピーして UI へ渡す。
- 割合の分母: 論理プロセッサ数はスナップショットの `CpuThreads`（[uCollector.pas:90](../src/metrics/uCollector.pas#L90)）、物理メモリ総量は `MemTotalBytes`（[uCollector.pas:104-105](../src/metrics/uCollector.pas#L104)）。
- **`TDashboardForm` に破棄処理が無い。** デストラクタも `OnDestroy` も無く（`.dfm` のイベントは `OnClose`/`OnCloseQuery`/`OnCreate`/`OnResize`/`OnShow`/`OnHide` のみ、[uDashboardForm.dfm:17-22](../src/dashboard/uDashboardForm.dfm#L17)）、フォームの解放は MainForm の `FreeAndNil(FDashboardForm)`（[uMainForm.pas:595](../src/uMainForm.pas#L595)）。
- **閉じる操作は `caHide`**（[uDashboardForm.pas:771](../src/dashboard/uDashboardForm.pas#L771)）で、フォームのフィールドは次の表示まで残る。
- `.dfm` に `KeyPreview` も `OnKeyDown` も無い。
- ヘッダーの高さを決めているのは `FormCreate`（[uDashboardForm.pas:140](../src/dashboard/uDashboardForm.pas#L140)）と `ApplyDpiChromeFor`（[uDashboardForm.pas:328-329](../src/dashboard/uDashboardForm.pas#L328)）の 2 か所。本体の上端は `LayoutContent` の `BodyTop := FHeaderPaint.Height + Met.Margin`（[uDashboardForm.pas:547](../src/dashboard/uDashboardForm.pas#L547)）。テーマ切替時の再描画は `ApplyTheme` の `Invalidate` 群（[uDashboardForm.pas:501-512](../src/dashboard/uDashboardForm.pas#L501)）。
- **`FormatBytesGiB` は常に GB 表記**（[uMetricsTypes.pas:257-268](../src/metrics/uMetricsTypes.pas#L257)）。数十 MB のプロセスは「0.05 GB」になるため、プロセスのメモリ列には使えない。
- **PDH の整形値は既定で 100 に切り詰められる。** `uGpuCollector` は `PDH_FMT_DOUBLE` 単独で配列を取っている（[uGpuCollector.pas:216](../src/metrics/uGpuCollector.pas#L216)）。`% Processor Time` は 1 コア＝100% なので、複数コアを使うプロセスは `PDH_FMT_NOCAP100` を付けないと 100 で頭打ちになる。
- ユニットの登録は `DiskLED.dpr` の `uses` と `DiskLED.dproj` の `<DCCReference>`（[DiskLED.dproj:132-139](../DiskLED.dproj#L132)）の両方。

### 方針

**1. ページ切替（`uDashboardForm.pas`）**
- `TDashboardPage = (dpOverview, dpProcess)` と `FPage` を持つ。ヘッダーの下にタブ行 `FTabPaint: TPaintBox`（`alTop`。高さは `THudMetrics` に `TabHeight` を足す、[uDashboardTheme.pas:213-222](../src/dashboard/uDashboardTheme.pas#L213) と同じ `ScalePx` 方式）を置き、自前描画する（選択中は `TextPrimary`＋アクセント色の下線、非選択は `TextMuted`）。`OnMouseDown` でタブの矩形を判定して `SetPage` を呼ぶ。Ctrl+Tab／Ctrl+Shift+Tab でも切り替える（`KeyPreview`）。
- `SetPage` は概要ページの 10 個のコントロールとプロセスページのコントロールの `Visible` を入れ替え、`LayoutContent` をページ別に分岐させる。
- タブ行の高さは `FormCreate`・`ApplyDpiChromeFor`・`LayoutContent` の `BodyTop` の 3 か所に反映する。`alTop` が 2 つ並ぶので、`FTabPaint.Top` をヘッダーの下に置いてから `Align` を設定し、並び順を固定する。`ApplyTheme` の `Invalidate` 群にタブ行とプロセスページを足す。
- Ctrl+Tab は `KeyPreview := True`＋`OnKeyDown` で受ける。フォームに届かない場合は `CM_DIALOGKEY` のメッセージハンドラで受ける（`TPageControl` と同じ方式。要実機確認）。
- 概要ページが非表示の間は、カードと右カラムの再描画（`RefreshData` の `Invalidate` 群、`MeterTimerTick`）を省く。履歴は MainForm 側で積まれ続けるので、概要に戻ったときグラフは途切れない。
- 選んだページは ini に保存しない（ダッシュボードは常に概要ページで開く）。閉じても `FPage` は残るので、`FormShow` で概要ページに戻す。保存するのは更新周期（`ProcessIntervalSec`）だけ。

**2. 収集層（新規 `src/metrics/uProcessCollector.pas`）**
- `TProcessCollector` は専用のワーカースレッドで、選んだ更新周期（3／5／10 秒、`SetInterval`）ごとに PDH の `\Process V2(*)\` から `% Processor Time`・`Working Set - Private`・`IO Read Bytes/sec`・`IO Write Bytes/sec` を `PdhGetFormattedCounterArrayW` で取る（バッファ拡張の作法は `uGpuCollector` と同じ）。`% Processor Time` は `PDH_FMT_DOUBLE or PDH_FMT_NOCAP100` で取り、100 を超える値をそのまま受ける（定数値は Windows SDK の `pdh.h` で確認して宣言する）。
- インスタンス名 `名前:PID` の最後の `:` より前を名前として合算し、件数も数える。`_Total`・`Idle` は除外する。合算後、3 種それぞれの上位 5 件と代表 PID を `TCriticalSection` 越しのコピー（`CopyTop`）で UI に渡す。
- **プロセスページ表示中だけ収集する**（`SetActive`）。概要ページ表示中やダッシュボード非表示中は PDH クエリを閉じ、スレッドはイベント待ちで止める。平常時のコストはゼロ。
- `TMetricsSnapshot` には入れない。スナップショットはガジェットのフレームごとの `Collect`（[uMainForm.pas:1031](../src/uMainForm.pas#L1031)）で回るため、1 Hz の別系統として `TDashboardForm` が所有する。`TDashboardForm` に `destructor Destroy; override` を足し、そこでスレッドを止めて待ち合わせてから解放する（`TPingCollector.Destroy` と同じ手順）。`FormHide` でも `SetActive(False)` にする。
- `Process V2` のカウンタ追加に失敗した OS（Windows 10 の一部版の可能性、未確認）は旧 `\Process(*)` へフォールバックする。名前で合算するので、旧セットのインスタンス名の重複（項目8）は合算されるだけで問題にならない。フォールバック時は PID を取らず、アイコンは全行を既定のアプリアイコンにする。
- 実行中の PDH 失敗は `uGpuCollector` と同じく連続失敗で再初期化する。
- `uProcessCollector.pas` は `DiskLED.dpr` の `uses` と `DiskLED.dproj` の `<DCCReference>` の両方に足す。

**3. 詳細とアイコン**
- コミット・ハンドル・スレッドは PDH の `Private Bytes`・`Handle Count`・`Thread Count` を同じクエリに足して取る。合算行のため、名前ごとに全 PID を持つ。
- 名前ごとにキャッシュする。初回だけワーカーで代表 PID を `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` で開き、`QueryFullProcessImageNameW`（パス）・`OpenProcessToken`＋`GetTokenInformation`（`TokenUser` からユーザー名、`TokenElevation` から昇格）・`IsWow64Process`（32bit か）を取る。同じくワーカーで `GetFileVersionInfoW`／`VerQueryValueW` から説明・会社名・バージョン・製品名・著作権を読む（ファイル I/O なので UI スレッドに載せない）。言語は `\VarFileInfo\Translation` の先頭の言語・コードページを使う。
- ウィンドウタイトルはキャッシュせず、毎回ワーカーで `EnumWindows` から PID→タイトル（表示中・所有者なし・タイトルあり）を作って引く。DiskLED 自身のウィンドウは除く（自プロセスのウィンドウへの `GetWindowText` は UI スレッドへメッセージを送るため、終了時にスレッドの終了待ちと行き詰まる）。
- アイコンは UI スレッドで、パスから `SHGetFileInfo` で作る（COM 初期化済みのスレッドで呼ぶため）。開けないプロセス（非昇格で約半数、項目8）は既定のアプリアイコン（`SHGetStockIconInfo(SIID_APPLICATION)`）にする。
- 高 DPI では大アイコンを取り、`DrawIconEx` で行の高さに合わせて描く。
- キャッシュした `HICON` はフォーム破棄時に `DestroyIcon` で解放する。`QueryFullProcessImageNameW` などの API 宣言は、PDH と同じくユニット内に `external` で持つ。

**4. 描画（`uDashboardPainter.pas`）**
- `DrawProcessTop` を足す。カード枠（既存の `FillRoundRect`/`StrokeRoundRect`）＋見出し＋N 件（`ProcessRowSlots` が列の高さから決める）で、1 列＝1 リソース。1 件の行構成は決定事項のとおり（2〜4 行目は `TextMuted`、長い場合は `Ellipsize`）。件の間は細い区切り線。各件の矩形を返し、フォーム側でマウス位置からツールチップを切り替える。値は次のとおり（項目8 の「絶対値・割合」はここで満たす）:
  - CPU: アイコン｜名前 (件数)｜システム比 %（`% Processor Time ÷ CpuThreads`）
  - メモリ: アイコン｜名前 (件数)｜プライベート ワーキング セット（MB／GB を切り替える整形関数を `uMetricsTypes.pas` に新設）｜物理メモリ比 %
  - I/O: アイコン｜名前 (件数)｜読み｜書き（`FormatRateBps`、[uMetricsTypes.pas:205](../src/metrics/uMetricsTypes.pas#L205)）
- 名前は既存の `Ellipsize`（[uDashboardPainter.pas:200-211](../src/dashboard/uDashboardPainter.pas#L200)）で切り詰める。開いた直後など値が無い間は各件を「—」にする。
- 値の列見出しは独立した行にせず、カードの見出し行の右側に載せる。
- 更新周期の切替（「更新 3秒 5秒 10秒 停止」）はタブ行の右端に自前描画し、クリックで `SetInterval` と ini 保存（周期のみ）、または `SetPaused` を行う。プロセスページ表示中だけ出す。
- 文字列は `uAppStrings.pas` に JA/EN で足す（タブ名・列見出し・値の見出し・更新周期・「取得できません」）。

**5. 文書**
- `docs/DESIGN.md` のダッシュボード節（`docs/DESIGN.md:300-336`）と `.cursor/rules/dashboard-regions.mdc` に、ページ（概要／プロセス）とタブ行を追記する。公開文書（`public_docs/` の FEATURES・USAGE、JA/EN）はリリース時に更新する。

### 実装ステップ

ブランチは `work/3.3.0-7-process-page`。各ステップの終わりに IDE で Win64 Release をビルドして確認する。

| # | 内容 | 主なファイル | ビルド後に見ること |
|---|---|---|---|
| 1 | ページ切替とタブ行（プロセスページは空の枠だけ） | `uDashboardForm.pas`、`uDashboardTheme.pas`（`TabHeight`）、`uDashboardPainter.pas`（タブ行の描画）、`uAppStrings.pas` | クリックと Ctrl+Tab で切り替わる。概要に戻って履歴が途切れない。DPI 変更で崩れない |
| 2 | 収集層（`Process V2` のみ。NOCAP100・名前合算・上位 5・`SetActive`） | 新規 `uProcessCollector.pas`、`DiskLED.dpr`、`DiskLED.dproj`、`TDashboardForm` のデストラクタ | 終了時に固まらない。概要表示中は収集が止まる |
| 3 | 3 列×5 件の描画（詳細・アイコンなし）と更新周期の切替 | `uDashboardPainter.pas`（`DrawProcessTop`・周期の切替）、`uMetricsTypes.pas`（MB／GB 整形）、`uProcessCollector.pas`（`SetInterval`）、`uSettings.pas`（`ProcessIntervalSec`） | タスクマネージャーとの比較。周期の切替と保存。ライト／ダーク。最小サイズ |
| 4 | 詳細（4 行構成・ツールチップ）とアイコン、高さに応じた件数、更新の停止 | `uProcessCollector.pas`、`uDashboardForm.pas`、`uDashboardPainter.pas` | ウィンドウタイトル・ユーザー・コミット等が出る。開けないプロセスが「詳細を取得できません」と既定アイコンになる。広げると件数が増える。125〜200% でにじまない |
| 5 | 旧 `\Process(*)` へのフォールバック（アイコンは既定のみ） | `uProcessCollector.pas` | Windows 10 実機で表示される |
| 6 | 文書 | `docs/DESIGN.md`、`.cursor/rules/dashboard-regions.mdc` | — |

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- タブのクリックと Ctrl+Tab で概要とプロセスが切り替わり、ちらつかないこと。概要に戻ったとき履歴グラフが途切れていないこと。
- プロセスページの CPU とメモリの値が、タスクマネージャーの「プロセス」タブとおおむね一致すること（CPU はシステム比、メモリはプライベート ワーキング セット）。I/O の段は全 I/O の値なので、タスクマネージャーの「ディスク」列とは比べない。
- 複数コアを使い切るプロセス（動画エンコード等）で、CPU のシステム比が「100 ÷ 論理プロセッサ数」% を超えて表示されること（100 で頭打ちになっていないこと）。非昇格で `svchost` などのサービスも出ること。開けないプロセスは既定アイコンになること。
- 概要ページ表示中とダッシュボード非表示中に、プロセス収集が止まっていること（DiskLED 自身の CPU 使用率が上がらない）。
- ライト／ダーク切替、125／150／200% DPI、最小サイズ（800×600 DIP）で、3 列×5 件が崩れず収まること（最小サイズ付近では 4 行目のパスが省かれる）。ウィンドウを縦に広げると件数が 6 件、7 件と増え、1 件の高さがほぼ変わらないこと。
- 更新周期を 3／5／10 秒に切り替えると、その間隔で値が変わること。再起動後も選んだ周期のままであること。
- Windows 10 実機で `Process V2` が無い場合に、旧 `Process` へのフォールバックで表示されること。

### 見積り

ページ切替・タブ行 1〜2 日、収集層（ワーカー・PDH・合算・フォールバック）2〜3 日、描画・アイコン 2〜3 日、実機調整 1〜2 日。合計 1〜2 週間（項目8 の表示分を含む）。

## 8. プロセス別の CPU／メモリ消費量（絶対値・割合）（完了）

各プロセスの CPU 使用率とメモリ使用量を、絶対値（%・MiB）と割合（システム全体に対する %）で取得し、ダッシュボードで見せる。**収集層・表示とも項目7で実装する**（項目7のプロセスページが CPU のシステム比、メモリのプライベート ワーキング セットと物理メモリ比を列に持つ）。本節は収集経路の実測記録。

### 検証結果（実機: Windows 11 26200・非昇格で実測。Windows 10 は未確認）

- **Win32 経路（`OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)` ＋ `GetProcessTimes`/`GetProcessMemoryInfo`）は全プロセスを取れない。** 523 プロセス中 284（約 54%）しか開けず、残り 238 は開けなかった（サービス・別セッション・保護プロセス等）。開けたものは `GetProcessTimes`・`QueryProcessCycleTime`・`GetProcessIoCounters`・`GetProcessMemoryInfo`（`PROCESS_MEMORY_COUNTERS_EX2` の `PrivateWorkingSetSize` 含む）がすべて成功した。→ 一覧の約半数が「取得不可」になり、TOP5 にもならない。
- **PDH の `Process V2` なら全プロセスが取れる。** `\Process V2(*)\% Processor Time`・`Working Set - Private`・`Working Set`・`Private Bytes`・`IO Read Bytes/sec`・`IO Write Bytes/sec` が約 513 インスタンス分すべて有効（`PdhAddEnglishCounterW` は成功）。インスタンス名は **`名前:PID`**（例 `AdobeIPCBroker:1852`）で一意。`ID Process` カウンタは `Process V2` には無い（PID はインスタンス名から取る）。PowerShell の `Get-Counter` は無効サンプル混在で例外にするが、PDH API 直叩きでは各インスタンスの `CStatus` で個別に判定でき、問題なく取れた。
- **旧 `Process` カウンタセットはインスタンス名が一意にならない。** 本機の `\Process(*)\...` は `svchost` が同名で複数並び（511 インスタンス・重複除去後 228 名、`#1` 等の接尾辞なし）、名前をキーにした辞書だと**衝突して欠落する**。旧セットを使う場合は `ID Process` と配列添字で突き合わせる必要があり、`Process V2` が無い OS のフォールバックとしてのみ検討する。`Process V2` が Windows 10 のどの版から使えるかは**未確認**（Microsoft の資料で要確認、または Win10 実機で確認）。
- **PDH の CPU は「1 コア＝100%」**（本機で 1 コア飽和のプロセスが 100.0% を返した。この実測は `PDH_FMT_NOCAP100` 無しのため、複数コア使用時に 100 を超える値は未確認。項目7 の実装で `PDH_FMT_NOCAP100` を付けて確認する）。システム全体に対する割合は `÷ 論理プロセッサ数`（[uCpuCollector.pas:29](../src/metrics/uCpuCollector.pas#L29) の `Threads`）。メモリの割合は `Working Set - Private ÷ 物理メモリ総量`（`GlobalMemoryStatusEx`、[uMemCollector.pas:59](../src/metrics/uMemCollector.pas#L59)、スナップショットの `MemTotalBytes`）。タスクマネージャーのメモリ列と同じ「プライベート ワーキング セット」に相当。
- **コスト:** PDH（3 カウンタ × 約 517 インスタンス）で `PdhCollectQueryData` 約 13 ms＋配列取得 約 3 ms（定常 1 サイクル平均 約 14 ms。PowerShell 経由の単発計測なので目安）。15 fps の表示タイマー（約 66 ms 周期）で毎フレーム回す量ではない。**1 Hz 程度で収集**する。既存の GPU 収集は同種のワイルドカード PDH を UI スレッド上で 900 ms 間隔（[uGpuCollector.pas:62](../src/metrics/uGpuCollector.pas#L62) `CSampleIntervalMs`）で回しており、プロセス別も同じ間隔で足りるが、GPU 分と合わせて 1 サイクル約 30 ms を UI スレッドに載せることになるので、**ワーカースレッド化（Ping と同じ流儀）を第一候補**とする。参考: Win32 ループは開けた 275 プロセスで約 5 ms、`Process.GetProcesses`（`NtQuerySystemInformation` 系）は約 10 ms で 511/512 プロセスのワーキングセットが取れるが、後者は非公開色の強い API で、README の「一般権限・公式 API 優先」方針（[README.md:28](../README.md#L28)）から外れるため採らない。
- 収集ユニット・ワーカースレッド化・フォールバックの設計は項目7 の方針 2 を参照。
- ダッシュボード以外（ガジェット本体・トレイ）へは出さない。

### 見積り

項目7 に含む。

## 10. 右クリックメニューの整理（表示系の設定をオプションへ移す）（完了）

右クリックメニュー（メイン窓とトレイアイコンで共用）から、「表示モード3択」と「表示倍率」を外し、設定系はオプション画面へ寄せる。メニューには日常的に使う操作だけを残し、後半の並びを整理する。

### 現状（実ソース確認済み）

- メニューは `FPopup` 1 つを本体（[uMainForm.pas:406](../src/uMainForm.pas#L406)）とトレイアイコン（[uMainForm.pas:485](../src/uMainForm.pas#L485)）で共用している。メニュー構築は `uMainForm.pas:644` 以降。
- 表示モードの3択（ウィンドウのみ／ウィンドウ＋トレイ LED／トレイ LED のみ）は `FMiWindowOnly`／`FMiWindowTrayLed`／`FMiTrayOnly`（グループ 4、[uMainForm.pas:681-702](../src/uMainForm.pas#L681)）。切替は `miWindowOnlyClick`（[uMainForm.pas:1219](../src/uMainForm.pas#L1219)）・`SetWindowTrayState`（[uMainForm.pas:1541](../src/uMainForm.pas#L1541)）・`EnterTrayOnly`（[uMainForm.pas:1560](../src/uMainForm.pas#L1560)）。
- 表示倍率は `FMiScale` の子項目（自動／100／150／200%、[uMainForm.pas:708-716](../src/uMainForm.pas#L708)）。`miScaleClick`（[uMainForm.pas:1234](../src/uMainForm.pas#L1234)）が即時に `FSettings.Scale` を書き、`ApplyDpiScale`（[uMainForm.pas:811](../src/uMainForm.pas#L811)）・再配置・`PersistSettings` まで行う。
- 外した後も落ちないよう、項目の同期処理には既に nil ガードがある（`FMiWindowTrayLed` は [uMainForm.pas:1031](../src/uMainForm.pas#L1031)、`FMiScale` は `SyncScaleMenu` の [uMainForm.pas:1058](../src/uMainForm.pas#L1058)）。
- 着手前の後半の順は「ダッシュボード → Ping結果表示 → オプション → 位置をリセット → 区切り → 更新（`FMiUpdate`、通常は非表示）→ 終了」（[uMainForm.pas:718-751](../src/uMainForm.pas#L718)）。
- オプション画面の「全般」タブ（[uOptionsForm.dfm:30](../src/uOptionsForm.dfm#L30)）には「ウィンドウ」カード（`CardWindow`、キャプション `opt.group.window`、[uAppStrings.pas:97](../src/uAppStrings.pas#L97)）がある。「表示」タブ（[uOptionsForm.dfm:128](../src/uOptionsForm.dfm#L128)）には `CardFps`・`CardScale` があるが、`CardScale` は「ネット速度の反応」（`SpeedScale`）であり表示倍率とは別物。
- オプションの確定は `BtnOkClick`（[uOptionsForm.pas:524](../src/uOptionsForm.pas#L524)）。
- 表示モードや倍率の保存キー（`WindowHidden`／`TrayLed`／`Scale`）は既存のものをそのまま使い、**設定キーは増やさない**。

### 方針

- **全般タブ「ウィンドウ」カードに表示モードの3択ラジオを移す**（ウィンドウのみ／ウィンドウ＋トレイ LED／トレイ LED のみ）。既存の「常に手前に表示」等と同じ並びに置く。
- **表示タブに「表示倍率」（自動／100%／150%／200%）を移す**。文字列は既存の `menu.scale`（[uAppStrings.pas:63](../src/uAppStrings.pas#L63)）を流用し、`CardScale`（ネット速度の反応）とは別カードにする。
- 両方とも**オプションの OK で確定**する。確定時に、表示モードは既存の `SetWindowTrayState`／`EnterTrayOnly` を呼び、倍率は `miScaleClick` の処理（倍率反映・再配置・保存）を呼び出し側から共通で使う形に寄せる。メニュー側の同処理は削除されるので重複は残らない。
- **メニュー後半の順序**（上記2項目を外したうえで）: 1. 位置をリセット ／ 2. ダッシュボード ／ 3. オプション ／ 区切り ／ 4. 終了（「Ping結果表示」は項目14 で廃止）。`FMiUpdate` は通常非表示で、表示時は**区切りの直後・終了の直前**に出る。
- メニュー前半（表示サイズ コンパクト／フル、`DisplayMode` の各項目、[uMainForm.pas:644-679](../src/uMainForm.pas#L644)）は変更しない。
- 公開文書の更新: `docs/DESIGN.md:178`（右クリック項目の列挙）と `public_docs/FEATURES.md` の右クリック記述を新しい配置に合わせる。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- メイン窓の右クリックとトレイアイコンの右クリックの両方で、メニューが「コンパクト／フル・表示モード群 → 区切り → 位置をリセット／ダッシュボード／オプション → 区切り → 終了」の順になっていること。旧3択と「表示倍率」が出ないこと。
- 更新通知が出ている状態（`FMiUpdate` 表示時）で、「更新」項目が区切りの直後・終了の直上にあること。
- オプション「全般」→「ウィンドウ」で3択を変えて OK → 直ちに表示状態が切り替わること。Cancel → 元の状態のままであること。
- オプション「表示」→「表示倍率」を 自動 → 100% → 200% と変えて OK → 窓が再配置されること。125／150／200% DPI のそれぞれで、窓が画面外に出ないこと。Cancel → 倍率が変わらないこと。
- 「トレイ LED のみ」（窓を非表示）の状態でトレイ右クリック → オプションが開き、そこで「ウィンドウのみ」に戻すと窓が再表示されること。
- 旧メニュー項目を削除した後、起動・表示モード切替・終了で例外が出ないこと（上記の nil ガード経路）。

### 見積り

1〜1.5 日（配置換え・確定時処理の共通化・メニュー並べ替えが中心。`.dfm` 変更と実機確認を含む）。

## 11. トレイ LED の色に黄色を追加（完了）

トレイ LED の色の選択肢（現行は緑／青／赤）に黄色を足す。

### 現状（実ソース確認済み）

- トレイのアイコンはスキンと無関係の固定アセットで、`assets/tray/<色>/` に `diskOff.ico`／`diskOn.ico`／`netOff.ico`／`netOn.ico` の 4 個ずつ置いてある（`green`／`blue`／`red` の 3 フォルダ）。
- アイコンは `tools/generate-tray-icons.ps1` が機械生成する。色ごとの配色は `$Palette`（[generate-tray-icons.ps1:38-51](../tools/generate-tray-icons.ps1#L38)、消灯時の中心・縁と点灯時の中心・縁の 4 色）、生成する色の一覧は `$colors`（[generate-tray-icons.ps1:224](../tools/generate-tray-icons.ps1#L224)）。スクリプト冒頭の説明（[generate-tray-icons.ps1:4](../tools/generate-tray-icons.ps1#L4)、「3 色 × 2 × 2 = 12 個」）も色数を前提にしている。
- 設定は `[Tray] LedType`（[uSettings.pas:417](../src/uSettings.pas#L417)・[uSettings.pas:489](../src/uSettings.pas#L489)）。`NormalizeTrayLedType`（[uSettings.pas:138-143](../src/uSettings.pas#L138)）が `green`／`blue`／`red` 以外を `green` に戻す。
- 読み込みは `ReloadTrayIcons`（[uMainForm.pas:1172-1206](../src/uMainForm.pas#L1172)）が `tray\<LedType>\` を組み立てるだけで、色名の一覧は持っていない。
- オプション画面の「トレイ LED の色」カード（`CardTrayLed`、[uOptionsForm.dfm:362](../src/uOptionsForm.dfm#L362)）に、ラジオボタン `RbLedGreen`／`RbLedBlue`／`RbLedRed`（[uOptionsForm.dfm:439-464](../src/uOptionsForm.dfm#L439)）とプレビュー画像 `ImgLedGreen`／`ImgLedBlue`／`ImgLedRed`（[uOptionsForm.dfm:396-425](../src/uOptionsForm.dfm#L396)）が横に 3 つ並ぶ（116px 間隔、カード幅 400）。プレビューの読み込みは `LoadLedPreviewIcons`（[uOptionsForm.pas:227-254](../src/uOptionsForm.pas#L227)）、設定との対応は `BindSettings` 側の読み込み（[uOptionsForm.pas:475-480](../src/uOptionsForm.pas#L475)）と `BtnOkClick` 側の書き込み（[uOptionsForm.pas:631-636](../src/uOptionsForm.pas#L631)）。

### 方針

- 色名は `yellow`。`$Palette` に `yellow` を足し、`$colors` に加えてスクリプトを再実行し、`assets/tray/yellow/` の 4 個を生成する。既存 3 色のアイコンは再生成しても変わらないこと（差分が出ないこと）を確認する。配色は既存の 3 色と同じ考え方（消灯時は暗く沈め、警告色に見えないようにする。[generate-tray-icons.ps1:37](../tools/generate-tray-icons.ps1#L37) の赤と同じ扱い）で、実機のトレイで見て調整する。
- `NormalizeTrayLedType` の許可リストに `yellow` を足す。
- オプション画面: `RbLedYellow`／`ImgLedYellow` を足し、`LoadLedPreviewIcons`・`BindSettings`・`BtnOkClick` の色の対応に 1 つ足す。4 色の並べ方は項目12 の表の形に含める。文字列は `uAppStrings.pas` に JA/EN で足す（既存の緑／青／赤の文字列キーに合わせる）。
- 配布物: `assets/` 配下はフォルダごと同梱される前提だが、`tools/stage-dist.ps1`・MSIX・インストーラーで `assets/tray/yellow/` が漏れなく入ることを確認する。
- 公開文書（リリース時）: `public_docs/USAGE.md:68,146`・`FEATURES.md:27`（JA/EN）の「緑／青／赤」を更新する。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- オプションで黄色を選んで OK → トレイの LED が黄色になり、点灯・消灯の区別がはっきり見えること（ライト／ダークのタスクバーの両方で）。
- オプションの黄色のプレビュー画像が 125／150／200% DPI でにじまないこと。4 つのラジオとプレビューが重ならないこと。
- ini に `LedType=yellow` が保存され、再起動後も黄色のままであること。

### 見積り

0.5 日（アイコン生成と配色の調整、オプション画面に 1 つ足す配置変更）。

## 12. トレイ LED の色をディスクとネットで個別に指定（完了）

現行はトレイ LED の色が 1 つで、ディスクとネットの両方のアイコンに同じ色を使っている。これをディスク用とネット用で別々に選べるようにする。

### 現状（実ソース確認済み）

- 色の設定は `[Tray] LedType` の 1 つだけ（[uSettings.pas:88-90](../src/uSettings.pas#L88)）。
- `ReloadTrayIcons`（[uMainForm.pas:1172-1206](../src/uMainForm.pas#L1172)）は同じ `tray\<LedType>\` から、1 個目（ディスクまたはネット、[uMainForm.pas:1187-1194](../src/uMainForm.pas#L1187)）・2 個目（ネット、[uMainForm.pas:1195-1201](../src/uMainForm.pas#L1195)）・ドライブ別の元アイコン（`diskOff`／`diskOn`、[uMainForm.pas:1202-1205](../src/uMainForm.pas#L1202)。これに文字を重ねて各ドライブのアイコンにする、[uMainForm.pas:1369-1370](../src/uMainForm.pas#L1369)）を読んでいる。色ごとに `disk*`／`net*` が揃っているので、読み込み元のフォルダを用途別に分けるだけで個別指定できる。
- オプション画面の色選択は 1 行（項目11 の現状参照）。ラジオボタンは同じ親（`CardTrayLed`）に並んでいるので、2 行にするには行ごとに親（パネル等）を分けてグループを分ける必要がある。

### 方針

- **設定キー**: 既存の `[Tray] LedType` をディスク用として使い続け、ネット用に `[Tray] LedTypeNet` を足す。`LedTypeNet` が ini に無いとき（既存の利用者）は `LedType` と同じ色にする（更新しても見た目が変わらない）。正規化は `NormalizeTrayLedType` を共用する。
- **読み込み**: `ReloadTrayIcons` で、ディスクのアイコン（1 個目がディスクのとき・ドライブ別の元アイコン）は `LedType`、ネットのアイコン（1 個目がネットのとき・2 個目）は `LedTypeNet` のフォルダから読む。
- **オプション画面**: 「トレイ LED の色」カードを表の形にする。上段に 4 色（項目11 の黄色を含む）の 16px プレビュー（`diskOn.ico`、`LIM_SMALL`）と色名、その下に「ディスク」「ネットワーク」の行を置き、各色の列にラジオボタンを 1 つずつ並べる。行ごとに別パネルに入れてラジオのグループを分ける。2 行それぞれに 48px のプレビューを付ける形は、カードがタブの下端まで使っていて高さが足りないため採らない。ネットの表示を無効にしていてもネット行は選べるままにする（後でネットを有効にしたときに使われる）。下の「トレイ LED の情報」「ドライブ別 LED」の位置は変えない（[uOptionsForm.dfm](../src/uOptionsForm.dfm) は IDE で直接編集されることがあるので、着手前に最新を確認する）。
- 文字列は `uAppStrings.pas` に JA/EN で足す（行見出し「ディスク」「ネット」。既存の `ChkLedDisk`／`ChkLedNet` の文字列を流用できるか着手時に確認する）。
- 公開文書（リリース時）: `public_docs/USAGE.md` の「トレイ LED の色」の行（JA/EN）を、ディスク／ネット別の指定に合わせて直す。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- ディスクとネットを両方表示した状態で、ディスクを緑・ネットを黄色にして OK → 2 つのトレイアイコンがそれぞれの色になること。
- ネットのみ表示（1 個目がネット）のとき、1 個目のアイコンがネット用の色になること。
- ドライブ別 LED（C: 等）が、ディスク用の色で表示されること。
- 3.2.0 以前の ini（`LedTypeNet` が無い）で起動したとき、ネットのアイコンが従来の `LedType` と同じ色で表示されること。
- オプション画面の表（4 色のプレビュー・色名と、ディスク／ネットワークの 2 行のラジオ）が、125／150／200% DPI で重ならず収まること。ディスク行とネット行の選択が互いに干渉しない（片方を選ぶと他方の選択が外れる、が起きない）こと。

### 見積り

1 日（設定キーと読み込みの分岐は小さい。オプション画面の表の形への配置変更と実機確認が中心）。

## 13. リモートデスクトップ接続中のダッシュボードのちらつき解消（完了）

リモートデスクトップ越しにダッシュボードを表示すると、更新（1 Hz の値更新、約 5 Hz のドーナツ更新）のたびに表示がちらつく。項目7 以前から起きている既存の挙動。

### 現状（実ソース確認済み）

- ダッシュボードはフォームとカードの両方で `DoubleBuffered := True` を指定している（[uDashboardForm.pas:123](../src/dashboard/uDashboardForm.pas#L123)、[uDashboardCard.pas:76](../src/dashboard/uDashboardCard.pas#L76)）。
- VCL はリモートセッション中、この指定を無視する。`TWinControl.CanUseDoubleBuffering`（RAD Studio 37.0 の `source\vcl\Vcl.Controls.pas`）が `(FDoubleBufferedMode = dbmRequested) or not (Application.InRemoteSession and Application.SingleBufferingInRemoteSessions)` を返し、既定値（`DoubleBufferedMode = dbmDefault`、`SingleBufferingInRemoteSessions = True`）ではリモートセッション中にダブルバッファリングが切れる。描画結果のビットマップを毎回転送するより GDI の描画命令を送るほうが帯域が少ない、という VCL 側の判断。
- その結果、背景の消去と各要素の描画が画面に直接見え、ちらつきになる。
- ガジェット本体（`TMainForm`）も `DoubleBuffered := True`（[uMainForm.pas:330](../src/uMainForm.pas#L330)）で同じ条件に当たるが、リモート越しの実機確認でちらつきは見られなかった（Ping/Tracert 結果窓も同じ）。

### 方針

- ダッシュボードのフォームと `TDashboardCard` に `DoubleBufferedMode := dbmRequested` を指定し、リモートセッション中もダブルバッファリングを使う。`Application.SingleBufferingInRemoteSessions` はアプリ全体に効くので触らず、対象のコントロールだけに指定する。
- ガジェット本体・Ping/Tracert 結果窓はちらつかないため、指定を足さない。
- 代償としてリモート接続時の転送量は増える（更新のたびにカード単位のビットマップが送られる）。ダッシュボードは表示中だけ更新されるので、許容範囲と見込む。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- リモートデスクトップ越しにダッシュボードを開き、概要ページ・プロセスページともちらつかないこと。
- ローカル（リモートでない）での表示が従来と変わらないこと。
- リモート越しにガジェット本体・Ping/Tracert 結果窓がちらつくかを確認し、ちらつくものは同じ指定で解消すること。

### 見積り

0.5 日（指定は数行。リモート越しの実機確認が中心）。

## 14. Ping 結果ウィンドウをダッシュボードの「Ping/経路」ページに統合（完了）

個別の Ping 結果ウィンドウ（Tracert 表示）を廃止し、ダッシュボードの 3 つ目のページ「Ping/経路」にする（タブは「概要」「プロセス」「Ping/経路」）。目的は、**最終到達先までの往復時間が、経路上のどの区間でどれだけ費やされているか（区間遅延のバランス）を視覚的に見せる**こと。見せ方はブラウザの開発者ツールの Network タブのウォーターフォールに倣い、上部にグラフ、下部に一覧を置く。

### 決定事項

- **ページ名は「Ping/経路」**（英語は `Ping / Route`）。頻繁に使う機能ではないため、右クリックメニューの「Ping結果表示」は廃止し、メニューには置かない。入口はダッシュボードのタブと、概要ページの Ping サブセクション（クリックでこのページへ移る。指の形のカーソル）。旧版で「Ping結果表示」を使っていた利用者向けに、リリース時の CHANGELOG・USAGE（JA/EN）に移動先を明記する。
- **計測はこのページを表示している間だけ。** ダッシュボードを閉じる、または別のページに移ると計測を止め、何も送信しない。途中で離れた計測は打ち切って結果を捨てる。ページを開いた時点で 1 回計測する（自動繰り返しが「停止」でも）。前回の結果は計測時刻と一緒に残し、新しい結果が出るまで表示する。ガジェットの定期 Ping（Ping 段階表示）はこれと独立に従来どおり動く。
- **自動繰り返しは 1 分／5 分／10 分／停止**（既定は停止）。プロセスページの更新周期と同じく、このページ表示中だけタブ行の右端に出し、選んだ値は ini に保存する。加えて「今すぐ計測」を置く。
- **計測方式: 1 回の計測 = 3 ラウンド。** 各ラウンドで TTL 1〜N にほぼ同時に送る（ルーターの ICMP 応答の上限に当たらないよう約 20 ms ずつずらす）。各ホップの値は 3 回の中央値で比べ、最小・平均・最大・ジッター・損失率も同じ 3 回から出す。区間遅延は隣り合うホップの中央値の差。前回の計測結果と同じ TTL・同じアドレスのホップがあれば、中央値の差（前回比）を出す。
- **区間遅延の扱い:**
  - 各ホップの「持ち越される遅延」を、そのホップとそれ以降の全ホップの中央値のうち最小のものとする（経路に沿って減らない）。区間遅延はこれの 1 つ前のホップとの差で、マイナスにならない。応答の無いホップ（`*`）の分は、次に応答したホップの区間に自然にまとまる。
  - 横棒は「1 つ前のホップの持ち越される遅延から、そのホップの持ち越される遅延まで」で描く（棒の長さ＝区間遅延、最終行の右端＝全体の RTT）。
  - 中央値のうち持ち越される遅延を超える分は、ルーター自身の応答の遅れで経路の遅延ではないため、横棒の先にグレーの破線で描き、ツールチップで説明する。
- **グラフ（上部）:** 最上段に全体の RTT を区間ごとに色分けした内訳バー。その下に各ホップのウォーターフォール（区間の横棒＋最小〜最大の細線＋ルーター自身の応答遅れの破線）と時間軸、その下に凡例（区間の色、最小〜最大の線、破線の意味）。色分けはアドレス区分（LAN・CGNAT・グローバル）、事業者名の表示がオンのときはグローバルのホップを事業者ごとに分ける。新しい結果は、横棒が上の行から順に左端から伸びるアニメーションで表示する（Windows のアニメーション効果がオフなら行わない）。
- **一覧（下部）の列:** TTL／ホスト名（IP。逆引きできなかったことも表示）／区分（LAN・CGNAT・グローバル・リンクローカル）／応答の種類（TTL 超過・到達・宛先到達不能（ホスト／ネット／ポート）・タイムアウト）／損失率／区間遅延／RTT 中央値（最小〜最大）／ジッター／前回比／AS・組織名。1 件 2 行の構成とし、残りはツールチップ（計測開始からの開始・終了時刻、応答パケットの TTL など）。
- **事業者名（AS 番号）の表示は既定オフ。** このページでしか使わないため、オプション画面ではなく、このページのタブ行に「事業者名を表示」のスイッチを置く（オンの間は下線。ツールチップで外部の DNS サービスに問い合わせることを説明する）。「AS」は利用者に伝わりにくいので、表記は事業者名を先に、番号は括弧で後ろに出す（例「GIGAINFRA Softbank BB Corp. (AS17676)」）。設定キーは `[Dashboard] RouteLookupAs`。
  - 方式は Team Cymru の DNS サービス（`<逆順IP>.origin.asn.cymru.com`、IPv6 は 4 ビット単位で逆順にした `…origin6.asn.cymru.com` の TXT で AS 番号、`AS<番号>.asn.cymru.com` の TXT で事業者名）を Windows 標準の `DnsQuery_W` で引く。送るのはグローバル IP のホップだけ（LAN・CGNAT は送らない）。オフの間は何も送らない。
  - 結果は IP・AS 番号ごとに覚える。失敗した IP は 60 秒後に再問い合わせする。
  - オンの間、グローバルの各ホップには「事業者名」「事業者名を取得中…」「事業者不明」のいずれかを必ず出し、スイッチの状態と表示が食い違わないようにする。オンにしたときは再計測せず、表示中の結果のホップにすぐ問い合わせる。
  - IX や事業者境界のルーターは隣の事業者の番号で出ることがあるため、区間の目安として扱う。公開文書（NOTES など）に問い合わせ先と送る内容を書く。
- **IPv6 は、Ping の対象が IPv6 アドレスしか持たないときだけ** IPv6 で経路を測る（`Icmp6SendEcho2`）。IPv4 アドレスがあれば IPv4 で測る。IPv4／IPv6 を切り替える設定は作らない。
- **表示と動作を一致させる。** 設定と Ping 先を経路計測へ渡す処理は 1 か所にまとめ、ページ切替・各操作・1 秒ごとの更新・オプション画面の OK のすべてがそこを通る。このページの表示中に Ping 先が変わったら（オプションでの変更、既定ゲートウェイの変化）、すぐ計測し直す。タブ行のスイッチは表示中 1 秒ごとに描き直す。

### 現状（着手前のソース。旧ウィンドウと旧経路計測のファイルは本項目で削除済み）

- **Ping 結果ウィンドウ** は `TTraceRouteForm`（[uTraceRouteForm.pas:25](../src/uTraceRouteForm.pas#L25)）。開いたとき（`FormShow`、[uTraceRouteForm.pas:407-416](../src/uTraceRouteForm.pas#L407)）と「更新」ボタンでだけ Tracert を走らせる。一覧は `TListView` の 4 列（TTL・IP・ホスト名・RTT、[uTraceRouteForm.pas:82-85](../src/uTraceRouteForm.pas#L82)）。
- 開くのは右クリックメニューの `miPingResult`（[uMainForm.pas:685-688](../src/uMainForm.pas#L685)、文字列 `menu.ping_result`）→ `ShowTraceRouteForm`（[uMainForm.pas:883-890](../src/uMainForm.pas#L883)）。フォームは `FTraceRouteForm`（[uMainForm.pas:114](../src/uMainForm.pas#L114)）で、終了時に解放（[uMainForm.pas:596](../src/uMainForm.pas#L596)）。最前面の再設定の判定にも出てくる（[uMainForm.pas:831](../src/uMainForm.pas#L831)）。ユニットは `DiskLED.dpr:43` と `DiskLED.dproj:160` に登録。文字列は `trace.*`（[uAppStrings.pas:78-91](../src/uAppStrings.pas#L78)）。
- **経路計測** は `TTracertCollector`（[uTracertCollector.pas:58](../src/metrics/uTracertCollector.pas#L58)）。TTL を 1 から順に 1 回ずつ送り、各 TTL の応答を待ってから次へ進む（[uTracertCollector.pas:290-330](../src/metrics/uTracertCollector.pas#L290)、最大 30 ホップ・1 ホップ 1000 ms・連続 5 回無応答で打ち切り、[uTracertCollector.pas:90-92](../src/metrics/uTracertCollector.pas#L90)）。逆引きはホップごとの別スレッドで、`OnHostName` で後から届く（[uTracertCollector.pas:131-151](../src/metrics/uTracertCollector.pas#L131)）。応答の `Status` は「到達」と「TTL 超過」の区別にしか使っておらず（[uTracertCollector.pas:195-196](../src/metrics/uTracertCollector.pas#L195)）、宛先到達不能の種類や応答パケットの TTL（`TIcmpEchoReply.Options.Ttl`）は捨てている。
- **IPv4 のみ。** ICMP の宣言は `IcmpSendEcho` だけ（[uIcmpApi.pas:32-35](../src/metrics/uIcmpApi.pas#L32)）、名前解決は `gethostbyname` の IPv4 のみ（`ResolveIPv4`、[uHostResolve.pas:20-35](../src/metrics/uHostResolve.pas#L20)）。定期 Ping も同じ `ResolveIPv4` を使う（[uPingCollector.pas:473](../src/metrics/uPingCollector.pas#L473)）。
- 計測対象は `TMetricsCollector.CurrentPingTarget`（[uCollector.pas:215](../src/metrics/uCollector.pas#L215)）で、定期 Ping の対象（既定ゲートウェイの自動選択を含む）と同じ。
- **ダッシュボードのページ** は `TDashboardPage = (dpOverview, dpProcess)`（[uDashboardForm.pas:38](../src/dashboard/uDashboardForm.pas#L38)）。タブ行・ページ切替・タブ行右端の周期選択・表示中だけ動く収集の仕組みは項目7 で用意済み（`SetPage`、`DrawTabChoice`、`TProcessCollector.SetActive`／`SetPaused` と同じ流儀）。

### 方針

**1. 収集層（新規 `src/metrics/uRouteCollector.pas`。旧 `uTracertCollector.pas` は旧ウィンドウと一緒に削除）**
- 1 回の計測を「3 ラウンド × TTL 1〜N の同時送信」にする。ICMP は `IcmpSendEcho2`（完了イベント付きの非同期）で TTL ごとに投げ、約 20 ms ずつずらす。宛先に到達した TTL より先は送らない（1 ラウンド目で到達 TTL を確定させ、2 ラウンド目以降はそこまで）。
- ホップごとに 3 回分の RTT・応答の種類（`Status`）・応答パケットの TTL・応答元アドレスを集め、中央値・最小・平均・最大・ジッター・損失率と区間遅延を計算して、1 回の計測結果として UI へ渡す。応答元アドレスがラウンドで異なる（経路が分岐している）場合は、最も多いアドレスを代表にし、ツールチップに他のアドレスも出す。
- ワーカースレッドで動かし、`SetActive`（ページ表示中だけ）・計測周期・「今すぐ計測」を受ける。途中で非表示になったら打ち切る。逆引き（既存の非同期方式）と AS の問い合わせは、結果の確定後に IP ごとに行い、届いたら UI を更新する。
- IPv6: 対象が AAAA しか持たないとき `Icmp6CreateFile`／`Icmp6SendEcho2` で同じ計測をする（宣言は RTL に無いので自前で持つ）。IPv4 の名前解決は従来の `ResolveIPv4` のままにし、IPv4 が引けないときだけ `GetAddrInfoW` で IPv6 を引く。アドレスは IPv4・IPv6 とも文字列で扱う。
- アドレス区分（LAN・CGNAT `100.64.0.0/10`・グローバル・リンクローカル、IPv6 は ULA `fc00::/7`・リンクローカル `fe80::/10`）はアドレスから判定する。

**2. ページ（`uDashboardForm.pas`、新規 `src/dashboard/uRoutePainter.pas`）**
- `TDashboardPage` に `dpRoute` を足し、タブ行を 3 つにする。Ctrl+Tab の巡回も 3 ページにする。
- ページは上部のグラフ（内訳バー＋ウォーターフォール）と下部の一覧。描画は項目7 と同じく自前描画（`TPaintBox`）で、ツールチップは `THoverTip`。
- タブ行右端に「自動 1分 5分 10分 停止」と「今すぐ計測」を出す（このページ表示中だけ）。設定キーは `[Dashboard] RouteIntervalMin`（0＝停止、1／5／10）。
- ページ上部に、宛先・IP・ホップ数・全体の RTT・計測時刻・計測中の表示を出す（旧ウィンドウのヘッダー相当）。
- 一覧が入りきらないときはマウスホイールでスクロールし、右端に位置を示す細い棒を出す。

**3. 旧ウィンドウの廃止**
- `uTraceRouteForm.pas`／`.dfm` を削除し、`DiskLED.dpr`・`DiskLED.dproj` の登録、`FTraceRouteForm` と最前面判定の条件、`ShowTraceRouteForm` を外す。右クリックメニューの `miPingResult` と文字列 `menu.ping_result` も削除する。使わなくなる `trace.*` 文字列は整理する。

**4. 事業者名（AS 番号、既定オフ）**
- タブ行に「事業者名を表示」のスイッチを置く。設定キーは `[Dashboard] RouteLookupAs`（既定 0）。
- 問い合わせは `DnsQuery_W`（`DNS_TYPE_TEXT`）で、結果の TXT を `|` で区切って AS 番号・国・事業者名を取り出す。IP ごとに別スレッドで行い、結果の置き場所（参照カウント付き）は計測側と分ける。
- オンの間は UI から表示中のホップについて問い合わせ済みかを確かめ（`EnsureAsLookups`）、足りなければ問い合わせる。

**5. 文書**
- `docs/DESIGN.md` のダッシュボード節に「Ping/経路」ページを追記する。公開文書（`public_docs/` の FEATURES・USAGE・NOTES・CHANGELOG、JA/EN）はリリース時に更新し、NOTES に事業者名の問い合わせ先と送る内容を、CHANGELOG・USAGE に「Ping 結果はダッシュボードの『Ping/経路』タブへ移動（概要の Ping の枠から開ける。右クリックメニューからは削除）」を書く。`README.md` の主な機能の「専用ウィンドウで Tracert のように…」の記述をページに合わせて直す。

### 実装ステップ

各ステップの終わりに IDE で Win64 Release をビルドして確認する。

| # | 内容 | 主なファイル | ビルド後に見ること |
|---|---|---|---|
| 1 | 「Ping/経路」ページの枠（タブ 3 つ、空のページ）と入口（概要の Ping サブセクションのクリック。メニュー項目は廃止） | `uDashboardForm.pas`、`uMainForm.pas`、`uAppStrings.pas` | 3 つのタブと Ctrl+Tab。概要の Ping の枠のクリックでこのページへ移る |
| 2 | 収集層の作り直し（3 ラウンド同時送信・統計・区間遅延・表示中だけ・周期） | 新規 `uRouteCollector.pas`、`uIcmpApi.pas` | 別ページ・ダッシュボード非表示で送信が止まる。終了時に固まらない |
| 3 | グラフ（内訳バー＋ウォーターフォール＋凡例＋アニメーション）と一覧、ヘッダー、周期選択と「今すぐ計測」 | 新規 `uRoutePainter.pas`、`uDashboardForm.pas`、`uSettings.pas` | 区間の棒が前の行の終わりから始まる。見かけだけの遅延がグレー破線になる |
| 4 | 旧 Ping 結果ウィンドウの削除 | `uTraceRouteForm.*`、`uTracertCollector.pas`、`uMainForm.pas`、`DiskLED.dpr`、`DiskLED.dproj` | 旧ウィンドウ関連が残っていない。メニュー・トレイから問題なく開く |
| 5 | 事業者名（既定オフ、ページのスイッチで有効化）と、表示・動作の一致 | `uRouteCollector.pas`、`uDashboardForm.pas`、`uMainForm.pas`、`uSettings.pas` | オフの間は問い合わせない。オンで事業者名が出る。どの順に操作してもスイッチの状態と表示が一致する |
| 6 | IPv6（対象が IPv6 のみのとき） | `uRouteCollector.pas` | IPv6 のみのホストで経路が出る |
| 7 | 文書 | `docs/DESIGN.md`、`README.md` | — |

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- 「Ping/経路」ページを開いた時点で 1 回計測し、自動繰り返しの各周期でその間隔ごとに計測されること。別のページに移る・ダッシュボードを閉じると送信が止まること（Resource Monitor 等で ICMP の送信が止まることを確認）。
- 区間の横棒が前の行の終わりから始まり、最終行の右端が全体の RTT と一致すること。内訳バーの区間の比率がウォーターフォールと一致すること。
- 途中のルーターだけ RTT が大きく次で戻るケースで、その行がグレーの破線になること。応答の無いホップがあっても、区間遅延が次のホップにまとめられること。
- 損失率・最小／最大・ジッター・前回比が、`tracert`／`pathping` の結果とおおむね整合すること。
- 事業者名の表示がオフの間は外部の DNS 問い合わせが出ないこと、オンにすると事業者名が出ること。オプションで Ping 先を変えた後や、計測中にスイッチを切り替えた後も、スイッチの状態と表示が一致すること。
- IPv6 のみの宛先で経路が出ること（ICMPv6 の応答の状態コードの位置を、もっともらしい方で読み分けている。`ipv6.google.com` で実機確認済み）。
- ライト／ダーク切替、125／150／200% DPI、最小サイズ（800×600 DIP）で崩れないこと。
- 旧 Ping 結果ウィンドウと右クリックメニューの項目が無くなり、ダッシュボード概要の Ping の枠のクリックでこのページへ移ること。

### 見積り

収集層の作り直し 3〜4 日、ページの描画 3〜4 日、旧ウィンドウ廃止・メニュー付け替え 0.5 日、AS 1 日、IPv6 1〜2 日、実機調整 1〜2 日。合計 1.5〜2 週間。

## 15. ドーナツグラフ内の値の縁取りをテーマに連動（完了）

ダッシュボード概要ページの左カラムの各セクションで、ドーナツグラフの中央に出す現在値（%・速度）は、読みやすさのため文字に縁取りを付けている。縁取りが黒に固定されているため、ライトテーマ（明るいカードの上）では黒い太枠が浮いて不自然に見える。縁取りの色をテーマに連動させる。

### 現状（実ソース確認済み）

- `TDashboardCard.Paint` が値を `TextOutOutlined` で描き、縁取り色に `clBlack` を直接渡している（2 値表示 [uDashboardCard.pas:212](../src/dashboard/uDashboardCard.pas#L212)・[uDashboardCard.pas:215-216](../src/dashboard/uDashboardCard.pas#L215)、1 値表示 [uDashboardCard.pas:228-229](../src/dashboard/uDashboardCard.pas#L228)）。縁取りの太さは `Met.Margin` 比例（[uDashboardCard.pas:199-201](../src/dashboard/uDashboardCard.pas#L199)）。
- `TextOutOutlined`（[uDashboardPainter.pas:130](../src/dashboard/uDashboardPainter.pas#L130)）は縁取り色を引数で受けるだけで、色の決め方は呼び出し側にある。
- 配色は `THudPalette`（[uDashboardTheme.pas](../src/dashboard/uDashboardTheme.pas)）にライト／ダークの 2 組があり、カードの地色は `Card`（ダーク `$261812`、ライト `RGB($FF, $FC, $F9)`、[uDashboardTheme.pas:133](../src/dashboard/uDashboardTheme.pas#L133)・[uDashboardTheme.pas:171](../src/dashboard/uDashboardTheme.pas#L171)）。

### 方針

- `THudPalette` に値の縁取り色（`ValueOutline`）を足す。ダークは現行どおり黒（見た目を変えない）、ライトはカードの地色（`Card`）にして、文字の周りを地色で抜く形にする。
- `TDashboardCard.Paint` の 3 か所の `clBlack` を `Pal.ValueOutline` に置き換える。テーマ切替時の再描画は既存の `ApplyTheme` の流れで行われる。
- ライトで縁取りが地色と同化して効かなくなる場合（ドーナツの色付き部分に文字が重なる箇所の読みやすさ）は、実機で見て色や太さを調整する。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- ライトテーマで、各セクションのドーナツ中央の値に黒い太枠が出ず、自然に読めること。値がドーナツの色付き部分に重なっても読めること。
- ダークテーマの見た目が従来と変わらないこと。
- ダッシュボードを開いたまま OS のライト／ダークを切り替えると、縁取りも追従すること。125／150／200% DPI でも同じであること。

### 見積り

0.5 日（色の追加と置き換えは数行。ライトでの見え方の調整が中心）。

## 16. ネット LED にアクセスランプ風のちらつきを付ける（完了）

ネットの通信が続いている間、ネット LED は点灯したままになり、データが流れている感じが出ない。イーサネットハブのアクセスランプのように、通信中も不規則に一瞬消える表示にする。対象はトレイとガジェットの両方。

### 現状（実ソース確認済み）

- ネットの活動判定は受信・送信どちらかが閾値を超えたかどうかの真偽値（`NetActivityOn`、[uDisplayPipeline.pas:356-358](../src/metrics/uDisplayPipeline.pas#L356)）。
- ネットの転送量（`NetInBps`／`NetOutBps`）は描画フレームごとに前回の取得からの差分で求めている（[uNetCollector.pas:599-604](../src/metrics/uNetCollector.pas#L599)、`Sample` から毎回呼ばれる `SampleFromEntries`、[uNetCollector.pas:562](../src/metrics/uNetCollector.pas#L562)）。1 秒平均ではなくフレーム単位の値なので、フレーム間の増減を比べられる。
- フレームの処理は `TimerTick`（[uMainForm.pas:997](../src/uMainForm.pas#L997)。間隔は fps 設定、既定 15fps）が `TDisplayPipeline.Update` を呼ぶ。

### 方針

- `TDisplayPipeline.Update` で毎フレーム、転送量を前フレームと比べて LED の表示状態を決める（判定は `NextBlink`、[uDisplayPipeline.pas:307](../src/metrics/uDisplayPipeline.pas#L307)。呼び出しは [uDisplayPipeline.pas:378-384](../src/metrics/uDisplayPipeline.pas#L378)）。表示状態は 3 つ（[uMetricsTypes.pas:141-143](../src/metrics/uMetricsTypes.pas#L141)）:
  - `NetBlinkOn`: 受信＋送信の合計。
  - `NetInBlinkOn`／`NetOutBlinkOn`: 受信・送信それぞれ。
- 判定は 3 つとも同じ:
  - 活動していなければ消灯。
  - 活動中は点灯。ただし前フレームより 10% 以上減ったフレームは 1 フレームだけ消灯する（しきい値は定数 `CNetBlinkDropRatio`、[uDisplayPipeline.pas:96](../src/metrics/uDisplayPipeline.pas#L96)）。
  - 消灯した次のフレームは必ず点灯に戻す（消灯が 2 フレーム続かない）。
- 一定周期の点滅にはしない（同じペースの点滅は機械的に見えるため）。小さな揺れで消えすぎないよう、しきい値で絞る。
- 使う LED:
  - トレイ（`NetBlinkOn`）: 1 個目がネットのとき（[uMainForm.pas:1143-1151](../src/uMainForm.pas#L1143)）と 2 個目（[uMainForm.pas:1399](../src/uMainForm.pas#L1399)）。
  - ガジェットの `NetActivity`・`NetTotal`（`NetBlinkOn`）、`NetIn`（`NetInBlinkOn`）、`NetOut`（`NetOutBlinkOn`）（[uMeterRenderer.pas:232-235](../src/view/uMeterRenderer.pas#L232)）。再描画の判定（[uMeterRenderer.pas:99-102](../src/view/uMeterRenderer.pas#L99)）も同じ値を見る。
- ディスクの LED は変えない。
- 公開文書（リリース時）: `public_docs/USAGE.md`・`FEATURES.md`（JA/EN）の LED の説明に、通信中のちらつき表示を書き足す。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- ダウンロードや動画再生など通信が続く状態で、トレイのネット LED が点灯を基本に不規則に一瞬消え、データが流れている感じに見えること。
- 通信が止まると消灯すること。
- ディスクとネットを両方表示した場合（2 個目）と、ネットのみ表示した場合（1 個目）の両方で同じ動きになること。
- ガジェット（ネットの LED を持つスキン）の合計のネット LED が、トレイと同じタイミングでちらつくこと。
- 受信・送信別の LED を持つスキンでは、受信・送信それぞれの LED が、その向きの通信量に合わせて別々にちらつくこと。

### 見積り

0.5 日（判定は数行。しきい値の見え方の調整が中心）。

## 17. 画面表示の用語・表記の統一（完了）

同じものを指す言葉や表記が画面によって違う箇所を、文字列表（`src/uAppStrings.pas`）で揃える。画面上の文字はすべてこの表から出ており、他のソースに日本語の表示文字列は無い（トレイのホバー表示の `CPU:`／`Disk:` などは 128 文字制限のため英字固定。[uMainForm.pas:1957-1959](../src/uMainForm.pas#L1957)）。

### 揃える基準

- ディスクの読み書きは「読込／書込」（ダッシュボード・プロセス表・累計表示と同じ）。ネットは「受信／送信」。
- 「閾値」は「しきい値」（オプションのグループ名・エラー文と同じ）。
- 日本語表示の中に英単語を混ぜない（`RAM`・`SWAP`・`GW`・`DHCP`・`RTT` など略語・固有の表記は除く）。
- 長音は既存の公開文書に合わせる（「ユーザー」「ルーター」は付ける。「フォルダ」「アダプタ」は付けない）。
- 英語の時間の短縮表記は `%dh %dm`／`%ds`（稼働時間・プロセスの更新周期と同じ）。日本語は `%d時間 %d分`。
- 英語のオプション画面の見出しは文頭のみ大文字（右クリックメニューとタブは各語頭大文字のまま）。

### 変更する文字列

- トレイのドライブ別ツールチップ: `読み／書き` → `読込／書込`（[uAppStrings.pas:72](../src/uAppStrings.pas#L72)）。
- オプション「Ping 判定しきい値」の各欄: `閾値` → `しきい値`（[uAppStrings.pas:132-134](../src/uAppStrings.pas#L132)）。
- オプション見出し（英語）: `Tray LED Color`／`Tray LED Info` → `Tray LED color`／`Tray LED info`（[uAppStrings.pas:112](../src/uAppStrings.pas#L112)、[uAppStrings.pas:117](../src/uAppStrings.pas#L117)）。
- ダッシュボード CPU 欄（日本語）: `User`／`Kernel` → `ユーザー`／`カーネル`（[uAppStrings.pas:187-188](../src/uAppStrings.pas#L187)）。
- ダッシュボードのネット速度グラフの凡例（日本語）: `In`／`Out` → `受信`／`送信`（[uAppStrings.pas:209-210](../src/uAppStrings.pas#L209)）。
- ヘッダーの累計表示（英語）: `Disk total R … W …` → `Disk total Read … Write …`（[uAppStrings.pas:226-227](../src/uAppStrings.pas#L226)）。
- 電源の残時間: 英語 `%dmin` → `%dm`、日本語 `%d時間%d分` → `%d時間 %d分`（[uAppStrings.pas:230-231](../src/uAppStrings.pas#L230)）。
- 「Ping/経路」ページの自動計測間隔（英語）: `%d min` → `%dm`（[uAppStrings.pas:252](../src/uAppStrings.pas#L252)）。
- 経路の応答種別: `ネット到達不能`／`Net unreachable` → `ネットワーク到達不能`／`Network unreachable`（[uAppStrings.pas:277](../src/uAppStrings.pas#L277)）。
- `layout.cfg` のエラー文: `数値readout` → `数値表示`（[uAppStrings.pas:179-181](../src/uAppStrings.pas#L179)）。

### 変えないもの

- ディスク情報カードの `Queue`（[uAppStrings.pas:213](../src/uAppStrings.pas#L213)）: 大きな数字の右に付く単位ラベルで、隣の `ms` と対になる（[uDashboardPainter.pas:850-851](../src/dashboard/uDashboardPainter.pas#L850)）。見出しは `キュー`（[uAppStrings.pas:214](../src/uAppStrings.pas#L214)）。
- 「ネット」と「ネットワーク」: 複合語と狭い欄の見出しは「ネット」（`ネット受信`・`ネット速度の反応`・カード見出しなど）、単独の項目名は「ネットワーク」で使い分けている。

### 公開文書（リリース時）

- `public_docs/EN/USAGE.md` のオプション表の `Tray LED Color`／`Tray LED Info` を新しい見出しに合わせる。
- `public_docs/FEATURES.md` の「閾値」を「しきい値」に揃える。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

日本語表示で:
- トレイのドライブ別アイコンのツールチップが `C: 読込 … ・ 書込 …` になること。
- オプション「Ping・ネットワーク」タブの 3 欄が「やや遅いしきい値 (ms)」などになり、欄からはみ出さないこと。
- ダッシュボード概要の CPU 欄の 4 行目が「ユーザー 12%   カーネル 3%」の形で、値が切れずに出ること。
- ネットのグラフの凡例が「受信／送信」になること。
- バッテリー駆動の PC では、電源欄の残時間が「1時間 23分」の形になること。

英語表示で（オプションで English にして再起動）:
- オプションの見出しが `Tray LED color`／`Tray LED info` になること。
- ダッシュボードのヘッダー右の累計表示が `Disk total Read … Write …` になり、切れずに収まること。
- 「Ping/経路」ページの間隔の選択肢が `5m` などになること。

### 見積り

0.5 日（文字列表の書き換えのみ）。

## 18. ネット速度の表示単位をビット（Kbps）に変更（完了）

ネットの転送速度をバイト単位（`KB/s`・`MB/s`、1024 区切り）で出しているのを、Windows 標準のタスクマネージャーと同じビット単位（`Kbps`・`Mbps`・`Gbps`、1000 区切り）に揃える。ネットの速度はビットで表すのが一般的で、リンク速度の表示（[uMetricsTypes.pas:332](../src/metrics/uMetricsTypes.pas#L332)）も既に `Mbps`／`Gbps`。

### 現状（実ソース確認済み）

- 速度の表示はディスク・ネット・プロセスの I/O で共通の `FormatRateBps`（[uMetricsTypes.pas:216](../src/metrics/uMetricsTypes.pas#L216)。`B/s`〜`GB/s`、1024 区切り）を使っている。
- ネットの速度を出しているのは、ダッシュボード概要のネットカードの受信・送信（[uDashboardForm.pas:1737-1738](../src/dashboard/uDashboardForm.pas#L1737)）と、ガジェットのホバー表示の `Net:` 行（[uMainForm.pas:1916](../src/uMainForm.pas#L1916)、[uMainForm.pas:1929](../src/uMainForm.pas#L1929)）。ホバー表示の文字列はトレイのツールチップにもそのまま使う（[uMainForm.pas:1987-1990](../src/uMainForm.pas#L1987)）。

### 方針

- ネット専用の `FormatNetRateBps`（[uMetricsTypes.pas:252](../src/metrics/uMetricsTypes.pas#L252)）を追加し、上の 2 か所だけ差し替える。入力はこれまでどおり Byte/s で、関数の中で 8 倍してビットにする。
- 表記はタスクマネージャーに合わせる: 最小単位は `Kbps`（0 は `0 Kbps`）、1000 で `Mbps`・`Gbps` に上がる。100 未満は小数 1 桁（`8.0 Kbps`）、100 以上は整数（`176 Kbps`）。単位と桁の切り替えは丸めた後の値で判断し、`1000 Kbps`・`100.0 Mbps` のような表記は出さない。
- 内部の値（`NetInBps` 等）は Byte/s のまま。メーターの正規化（`uRangeEngine.pas`）・LED の点灯判定（`CNoiseFloorBps`）・トレイのちらつき判定（項目16）は単位に依存しないため変えない。

### 変えないもの

- ディスクの速度（ダッシュボード・ホバー表示・トレイのドライブ別ツールチップ）とプロセスページの I/O 列は `FormatRateBps` のまま。プロセスの I/O はディスク以外も含む読み書き量で、ネット速度ではない。
- ヘッダーのネット累計（`FormatBytesGiB`、[uDashboardForm.pas:1807-1809](../src/dashboard/uDashboardForm.pas#L1807)）は速度ではなく量なのでバイト（GB）のまま。

### 公開文書（リリース時）

- `public_docs/` の本文にネット速度の単位を書いた箇所は無い。CHANGELOG（JA/EN）に単位の変更を書く。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

- ダッシュボード概要のネットカードの受信・送信が `Kbps`／`Mbps` で出て、通信していないときは `0 Kbps` になること。値が欄からはみ出さないこと。
- ダウンロード中の値が、同じ時刻のタスクマネージャー（パフォーマンス → イーサネット／Wi-Fi の送信・受信）とおおむね同じ桁・単位になること。
- ガジェットにマウスを乗せたときのホバー表示の `Net:` 行と、トレイアイコンのツールチップの `Net:` 行が `Kbps`／`Mbps` になること。
- ディスクの速度（ネットカードの隣のディスクカード、ホバー表示の `Disk:` 行）は `KB/s`／`MB/s` のままであること。

### 見積り

0.5 日（表示関数 1 つと呼び出しの差し替え）。

## 19. 計測値をタスクマネージャー等と揃える（完了）

専門ツール並みの精度は求めないが、タスクマネージャーなど一般的なツールと食い違う値は出さない。全収集ユニットを見直し、この PC（Core i9-12900K・64 GB・Killer E3100G 2.5GbE、Windows 11）で、同じ時刻にタスクマネージャーが使う値と照合した。

### 見つかった誤りと修正

| 対象 | 誤り（着手前） | 実測（この PC） | 修正 |
|---|---|---|---|
| ネット速度・ネット累計・ネットのメーター | `GetIfTable` がアダプターに付く NDIS フィルター（WFP Native MAC・QoS Packet Scheduler・WFP 802.3 MAC）を、同じ通信量を持つ別の行として返し、それを合計していた | 有線 1 枚が 4 行に数えられ、ちょうど 4 倍（実 1.6 Gbps → 表示 6.3 Gbps） | `GetIfEntry2` のフラグでフィルター行を除外（[uNetCollector.pas:306](../src/metrics/uNetCollector.pas#L306)、[uNetCollector.pas:505](../src/metrics/uNetCollector.pas#L505)）。アダプター一覧の表示からも外れる |
| リンク速度（アダプター一覧・ネットメーターの基準） | 32bit の `dwSpeed` を使っていたため 4.29 Gbps で頭打ち。未接続のアダプターの定格もメーターの基準に入っていた | 10GbE の仮想アダプターが 4294 Mbps | `GetIfEntry2` の 64bit 値を使い、基準は接続中のアダプターの最大値（[uNetCollector.pas:526](../src/metrics/uNetCollector.pas#L526)） |
| ネットの取りこぼし | 前回と同じ時刻（経過 0）のサンプルで、基準値だけ更新して転送量を捨てていた | — | 経過 0 のサンプルは基準値を更新しない（[uNetCollector.pas:583](../src/metrics/uNetCollector.pas#L583)） |
| CPU 使用率 | `GetSystemTimes` の稼働時間。タスクマネージャーはクロックを加味したプロセッサ使用率（`% Processor Utility`）を出す | 1 秒平均で DiskLED 8.7% に対しタスクマネージャー 13% 前後 | PDH `% Processor Utility` に変更（[uCpuCollector.pas:83](../src/metrics/uCpuCollector.pas#L83)、[uCpuCollector.pas:329](../src/metrics/uCpuCollector.pas#L329)）。User / Kernel の内訳は合計が使用率と一致するよう換算 |
| CPU 使用率の数値 | 数値はメーター針（上昇は速く下降は遅い）の、1 秒ごとのその瞬間の位置。1 フレーム（約 60 ms）の値を拾うため揺れ、高めに出る | — | 直近 1 秒の平均（`CpuUsageAvg`）を数値に使う（[uCpuCollector.pas:362](../src/metrics/uCpuCollector.pas#L362)、[uDisplayPipeline.pas:243](../src/metrics/uDisplayPipeline.pas#L243)）。メーターは従来どおりフレームごと |
| CPU クロック | `CallNtPowerInformation` の CurrentMhz の平均。現在の Windows では各コアの定格を返すだけで、実クロックではない | 常に 2.93 GHz（P コア 3.2 GHz と E コア 2.4 GHz の定格平均）。タスクマネージャー方式では 3.85 GHz | PDH `% Processor Performance` × `Processor Frequency`（[uCpuCollector.pas:397](../src/metrics/uCpuCollector.pas#L397)）。取れない間は定格だけを表示する（[uDashboardPainter.pas:510](../src/dashboard/uDashboardPainter.pas#L510)） |
| SWAP | `GlobalMemoryStatusEx` のページファイル欄を使っていたが、これはコミット（＝ダッシュボードの「コミット」欄と同じ数字） | SWAP 49%（33.2/67.7 GB）に対し、実際のページファイル使用率は 3.2%（132/4,096 MB） | PDH `Paging File(_Total)\% Usage` の生値（使用中／サイズ）に変更（[uMemCollector.pas:244](../src/metrics/uMemCollector.pas#L244)）。カウンタが取れない環境では、ダッシュボードの SWAP カードとホバー表示を「—」にする（ディスクのレイテンシと同じ扱い。[uDashboardForm.pas:1729](../src/dashboard/uDashboardForm.pas#L1729)） |
| メモリのスタンバイ | `GetPerformanceInfo` の SystemCache（システムのワーキングセットを含み、スタンバイリストとは別物） | 14.6 GB に対し実際のスタンバイは 16.1 GB | PDH `Memory\Standby Cache *` の合計（[uMemCollector.pas:241](../src/metrics/uMemCollector.pas#L241)）。空き（＝利用可能−スタンバイ）も正しくなる |
| ディスクのキュー・IOPS・アクティブ時間・レイテンシ | 1 フレーム（約 60 ms）の値。キューは瞬間値 | — | 別のクエリで 1 秒ごとに取り、1 秒の平均に（[uDiskCollector.pas:262](../src/metrics/uDiskCollector.pas#L262)）。キューは `Avg. Disk Queue Length`（[uDiskCollector.pas:179](../src/metrics/uDiskCollector.pas#L179)）。別のクエリを開けないときは読み書き速度と同じクエリに載せる（[uDiskCollector.pas:175](../src/metrics/uDiskCollector.pas#L175)） |
| ダッシュボードのディスク・ネットの速度 | 1 フレームの値をそのまま表示 | — | ホバー表示と同じ 1 秒平均（[uDashboardForm.pas:1735](../src/dashboard/uDashboardForm.pas#L1735)） |
| プロセス別 CPU | Process V2 の `% Processor Time`（稼働時間）。タスクマネージャーのプロセス一覧は使用率（全体の CPU と同じ基準） | — | 同じサンプル区間の全体の使用率／稼働時間の比で換算（[uProcessCollector.pas:788](../src/metrics/uProcessCollector.pas#L788)、[uProcessCollector.pas:884](../src/metrics/uProcessCollector.pas#L884)） |

### 問題が無かったもの

- メモリ使用率（物理）・コミット・GPU 使用率（タスクマネージャーと同じ集計）・ディスクの読み書き速度（PDH `PhysicalDisk(_Total)`）・ドライブ別の速度・ディスク累計・稼働時間・Ping（`RoundTripTime`）・電源・コア数／スレッド数・プロセス別のメモリ（Working Set - Private）。
- プロセス別の I/O はディスク以外も含む値で、見出しも「I/O」なので食い違いではない。

### 残るもの

- 物理アダプターではない WAN Miniport (IP/IPv6) は今も合計に含まれる。この PC では通信が 0 で確認できないが、PPPoE や VPN の環境で二重に数える可能性がある。

### 公開文書（リリース時）

- CHANGELOG（JA/EN）に、SWAP がページファイルの使用率になったこと、CPU 使用率・クロックがタスクマネージャーと同じ基準になったこと、ネットの速度・累計の修正を書く。`public_docs/FEATURES.md` の「SWAP（ページファイル相当）」はそのままで正しくなる。

### 実機で見ること（実装時。Win64 Release を IDE でビルド）

タスクマネージャー（パフォーマンス タブ）を横に並べて:
- ダウンロード中、ダッシュボードのネットカードとホバー表示のネット速度が、タスクマネージャーのイーサネットの送受信とおおむね同じ値になること（4 倍にならない）。ダッシュボードの「ネットワーク」欄に「…-WFP Native MAC Layer…」などの行が出ないこと。
- CPU 使用率（ガジェットの数値・ダッシュボード・ホバー表示）が、タスクマネージャーの CPU の値とおおむね同じで、1 秒ごとに落ち着いて変わること。
- ダッシュボード CPU 欄のクロックが、タスクマネージャーの「速度」とおおむね同じで、負荷に応じて変わること（常に 2.93 GHz ではない）。
- SWAP（ガジェット・ダッシュボード）が数 % 程度になり、ダッシュボードの SWAP 欄の量がページファイルのサイズ（この PC では 4 GB）になること。すぐ下の「コミット」欄とは違う数字になること。
- ダッシュボードのメモリ欄のスタンバイが、タスクマネージャーの「キャッシュ済み」より少しだけ小さい値（差は「変更済み」の分）になること。
- ダッシュボードのディスク情報（キュー・レイテンシ・IOPS・アクティブ）が、1 秒ごとに落ち着いて変わること。
- プロセスページの CPU 列が、タスクマネージャーの「プロセス」タブの CPU 列とおおむね同じになること。

### 見積り

1.5 日（収集ユニット 6 本の修正と照合）。
