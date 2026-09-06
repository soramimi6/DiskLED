# 3.1.2 予定（未実装）

公開ドキュメント（`public_docs/`）には予定している内容は書かない。実装が入り、利用者に見えるようになってから CHANGELOG（JA+EN）へ「実装済み」として書く。

3.1.1 は Microsoft Store の認定へ提出済みのため、以降に見つかった変更はこの 3.1.2 に積む。

一覧は優先度（高い順）、同順位内は工数目安（小さい順）で並べている。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 | 優先度 |
|---|---|---|---|---|---|
| 1 | Dashboard ウィンドウの画面外復帰 | 高（原因特定済み・実装プランも決定事項） | 低（小規模、既存関数の流用） | 半日未満 | 高 |
| 2 | assets 読み込みの堅牢化 | 高（アーキテクチャ変更は不要） | 中（既存パース関数群への横断的な変更） | 2〜3日＋実機検証 | 高 |
| 3 | 未使用アセットの削除 | 高 | 低（`git rm` のみ） | 半日未満 | 中〜高 |
| 4 | BMP → PNG 変換 | 高 | 低〜中（変換自体は容易だが色キー透過の実機確認が要る） | 半日程度 | 中 |
| 5 | 新スキン: アナログ VU メーター | 高（メーター描画自体は既存のスプライトストリップ方式で対応可） | 高（DiskIO/NetIO 合成パイプライン新設＋コンパクト／フルのパーツ出し分け機構という新エンジン機能が前提） | 未検証（コア変更＋layout.cfg拡張＋素材制作） | 中 |

## 1. Dashboard ウィンドウの画面外復帰

**モニター構成の変更（サブモニター取り外し等）で、Dashboard ウィンドウが画面外に出て操作できなくなる不具合を修正する。**

3.1.1 の実機最終検証で発見。メインウィンドウ（ガジェット本体）には既に画面内補正の仕組みがあるが、Dashboard には無い。

### 現状の確認結果

- メインウィンドウは `TMainForm.ApplyWindowBounds`（[uMainForm.pas:787](../src/uMainForm.pas#L787)）が `Self.BoundsRect` を `ConstrainAndSnapRect`（[uWindowPlacement.pas:127](../src/uWindowPlacement.pas#L127)）で画面内へ補正しており、右クリックの「位置をリセット」（`TMainForm.miResetPositionClick`、[uMainForm.pas:1099](../src/uMainForm.pas#L1099)）から手動でも呼べる
- Dashboard（`TDashboardForm`）は `ApplySavedDipBounds`（[uDashboardForm.pas:237](../src/dashboard/uDashboardForm.pas#L237)）が保存済みの `DashboardX/Y/W/H` をそのまま `SetBounds` するだけで、画面内チェックが一切無い。`FormCreate`（[uDashboardForm.pas:119](../src/dashboard/uDashboardForm.pas#L119)）内で最初の表示時にしか呼ばれない
- `TMainForm.ShowDashboard`（[uMainForm.pas:704](../src/uMainForm.pas#L704)）は `FDashboardForm` を一度だけ生成して使い回す（`.Create` は初回のみ、以降は `.Show` のみ）ため、`FormShow`（[uDashboardForm.pas:547](../src/dashboard/uDashboardForm.pas#L547)）は非表示→表示の遷移のたびに毎回呼ばれる
- `miResetPositionClick` はメインウィンドウの `BoundsRect` しか触っておらず、Dashboard には波及しない
- Ping 結果表示（`TTraceRouteForm`）は位置を保存せず毎回 `Position := poScreenCenter`（[uTraceRouteForm.pas:105](../src/uTraceRouteForm.pas#L105)）のため対象外（画面外に残る問題がそもそも起きない）

### 実装プラン（決定事項）

- **表示のたびの画面内補正**: `TDashboardForm.FormShow` に、`WindowState = wsNormal` のときだけ `BoundsRect` を画面内へ補正する処理を追加する。ドラッグ中の追従・スナップは不要（メイン側と違い常時ドラッグ制約を扱っている最中の枠ではないため、表示タイミングの一度きりでよい）。既存の `ConstrainAndSnapRect` をそのまま使うか、エッジスナップ無しの `ClampRectToWindowMonitor`（[uWindowPlacement.pas:137](../src/uWindowPlacement.pas#L137)）を使うかは実装時に決める（Dashboard は枠付きの通常ウィンドウでスナップ挙動は不要な可能性が高く、後者が有力）
- **「位置をリセット」からの波及**: `TMainForm.miResetPositionClick` に、`FDashboardForm <> nil` のときだけ Dashboard 側にも同じ画面内補正をかける呼び出しを追加する。Dashboard 側に `TMainForm.ApplyWindowBounds` 相当の公開メソッドを新設し、呼び出し後は `PersistDashboardDip`（[uDashboardForm.pas:252](../src/dashboard/uDashboardForm.pas#L252)）＋設定保存で新しい位置を残す
- Ping 結果表示は対象外（現状のままでよい）

見積り: 半日未満（小規模）。

## 2. assets 読み込みの堅牢化

`assets/` 以下の `layout.cfg` や画像ファイルに問題（設定ミス・必須項目欠落・任意項目の異常値・ファイル破損）があったときの挙動を洗い出した結果、現状は次の4パターンに分かれる。3.1.2 ではこの方針で統一する。

| パターン | 現状 | 3.1.2 での方針 |
|---|---|---|
| A. assets フォルダ自体が無い | 起動時に `MessageDlg` 表示＋`Application.Terminate` | **維持**（変更なし） |
| B. layout.cfg の必須項目欠落・重複・0件、および任意項目の不正値 | 必須項目（Width/Height/Bg）の欠落・重複・0件は A と同様に起動ブロックされるが、**任意項目（Frames/X/Y/MaskColor/Strength 等）の不正値は無検証でデフォルト値に黙ってフォールバックする** | 任意項目もできる限り事前検証し、異常値は A と同じ起動ブロック（`MessageDlg`＋`Application.Terminate`）にする |
| C. layout.cfg は正常だが参照先の画像ファイルが無い・壊れている | 例外は投げるが、**起動時の初回描画では未捕捉（クラッシュの恐れ）。起動後のモード切替時はVCL既定の例外処理でダイアログは出るがアプリは終了せず不完全な描画のまま残る** | 例外を捕捉し、A と同じ `MessageDlg`＋`Application.Terminate` にする |
| D. タスクトレイ用 `.ico`（TrayOff/TrayOn）が無い・壊れている | 例外を握りつぶしてアプリアイコン固定にフォールバック（`assets/LAYOUT.md` の仕様どおり） | **維持**（変更なし） |

### 技術的な裏付け（2026-09-06 時点、`src/view/uSkinLoader.pas` / `src/view/uAssetStore.pas` / `src/uMainForm.pas` / `DiskLED.dpr` を確認）

**A（現状維持）**: `TAssetStore.LocateRoot`（[uAssetStore.pas:117-148](../src/view/uAssetStore.pas#L117-L148)）が例外を送出し、`TMainForm.FormCreate` の `try`（[uMainForm.pas:301-312](../src/uMainForm.pas#L301-L312)）が `MessageDlg` 表示後 `Application.Terminate` する。変更不要。

**B（拡張対象）**:
- 必須項目チェックは既にある: `[Mode] Width`/`Height`/`Bg` のいずれかが空・0以下だと `LoadSkinLayout` が `err.layout_mode_incomplete` を送出し（[uSkinLoader.pas:347-348](../src/view/uSkinLoader.pas#L347-L348)）、この例外は `LoadDisplayModes` のループ内で捕捉されずに A と同じ `FormCreate` の `try` まで伝播する。つまり「1個のスキン設定ミスで起動ブロック」という経路は**既に存在しており、今回はこの経路自体は変えず、検証対象を広げるだけでよい**
- 任意項目は現状すべて「存在するのに不正な値」を検出していない: `ReadSprite`（[uSkinLoader.pas:168-197](../src/view/uSkinLoader.pas#L168-L197)）の `X`/`Y`/`Frames` は `Ini.ReadInteger` が内部で `StrToIntDef` を使うため、値が無い場合と壊れた文字列の場合が区別できず両方ともデフォルトに落ちる。`MaskColor` は `ParseColor`（[uSkinLoader.pas:51-78](../src/view/uSkinLoader.pas#L51-L78)）が不正な16進数なら黙って `ADefault`（黒）を返す。`ReadDigitValue`・`ReadBallisticChannel`/`ParseBallisticParams`（[uSkinLoader.pas:106-140](../src/view/uSkinLoader.pas#L106-L140)、`Strength` は範囲外でも `ClampStrength` が黙って丸める）・`ReadGraphLane`（[uSkinLoader.pas:260-289](../src/view/uSkinLoader.pas#L260-L289)、カンマ区切りの数が合わない／数値変換失敗のときは黙って `Enabled := False` にするだけ）も同様
- 対応方針: 各 `Read*` ヘルパーに「キーが存在する（`Ini.ValueExists`）のに値が不正」を検出する厳格チェックを追加する。キー自体が無い・空文字列は従来どおり「未使用」として許容し、デフォルト値に倒す（この区別が重要。存在しないキーまでエラーにすると既存レイアウトが軒並み壊れる）
  - 数値（X/Y/Frames/Width/Height/ValB/ValFontSize/Strength 等）: 存在するのに整数として解釈できない、または許容範囲外（`Frames<1`、`Strength` が 0–100 外、`Digits<1` 等）なら例外
  - 色（MaskColor/FontMaskColor/ValColor/Graph の各 `*Color`）: 存在するのに `#RRGGBB` 形式でも `cl` 接頭の VCL 色名でも解決できないなら例外
  - 真偽値（Transparent/ValFZ/ValSW/ValBold/Default）: 存在するのに `0/1/true/false/yes/no/on/off`（大小文字を問わない）のどれでもないなら例外
  - Ballistic の `Kind`（`vu`/`bar`/`peak` 以外の非空文字列）: 例外
  - `[Graph]` の `Cpu=X,Y,W,H` 形式: カンマの数が合わない、要素が数値でない、`W`/`H` が0以下、のいずれかなら例外（現状は黙って無効化しているだけ）
- エラーメッセージは「どのファイルの、どのセクション・キーが、どんな値で」失敗したかを含める必要がある。新しいエラー文字列 ID（例 `err.layout_value_invalid`、引数にパス・セクション・キー・生値を取る）を `uAppStrings.pas` に追加する
- **回帰リスクの確認が必須**: 既存4スキン（Original/Crystal/Metalic/Info Bar）の `layout.cfg` が、この厳格化後も無修正で通ることを実装時に確認する（現状の値は正常なはずだが、意図せず境界値に依存している箇所がないか要チェック）

**C（拡張対象）**:
- 画像読み込みは layout.cfg 解析時ではなく初回描画時の遅延ロード: `TAssetStore.Graphic`→`LoadGraphic`（[uAssetStore.pas:36-73](../src/view/uAssetStore.pas#L36-L73)）がファイル不在・破損時に例外を送出する
- 起動時: `TMainForm.FormCreate` 内の `ApplyMode(FSettings.Mode)` 呼び出し（[uMainForm.pas:349](../src/uMainForm.pas#L349)）→`Render`（[uMainForm.pas:831-843](../src/uMainForm.pas#L831-L843)）→`TMeterRenderer.DrawBackground`/`DrawMeters` の経路で発生するが、この呼び出しは A の `try` ブロック（309行目で終了）の**外**かつ `Application.Run` 開始前のため未捕捉。`DiskLED.dpr` にも `Application.CreateForm` を囲む `try` が無い（[DiskLED.dpr:63](../DiskLED.dpr#L63)）ため、素のクラッシュになりうる
- 起動後: 右クリックでのモード切替（`ApplyMode` がメッセージループ内で呼ばれる、[uMainForm.pas:943](../src/uMainForm.pas#L943)）では VCL既定の例外処理（`Application.OnException` は未設定）が拾ってダイアログを出すが、アプリは終了せず不完全な描画のまま動き続ける
- 対応方針: **`TMainForm.ApplyMode` 内の `Render` 呼び出しを try/except で囲み**、例外発生時は A と同じ `MessageDlg(E.Message, mtError, [mbOK], 0)` → `Application.Terminate` を行う。`ApplyMode` は起動時・モード切替時の両方の呼び出し元から共通で使われているため、**この1箇所を直せば両方のケースが同じ挙動になる**（呼び出し元ごとに個別の try/except は不要）
- 対象になる例外は `TAssetStore.Graphic` 由来のものすべて（背景・メーター・Ping・数値ビットマップフォント。`uDigitRenderer.DrawBitmapDigits`（[uDigitRenderer.pas:79](../src/view/uDigitRenderer.pas#L79)）経由のフォントビットマップ読み込みも `Render` の呼び出しツリー内に含まれるため同じ1箇所でカバーできる）
- ダッシュボード（`uDashboardForm.pas`/`uDashboardPainter.pas`）は `TAssetStore`/`uAssetStore` を一切参照しない自前 GDI 描画のため対象外（確認済み）

**D（現状維持）**: `LoadTrayIcon`（[uMainForm.pas:970-985](../src/uMainForm.pas#L970-L985)）が例外を握りつぶして空アイコンを返し、`UpdateTrayLed` が空判定してアプリアイコン固定にフォールバックする。変更不要。

### 見積り

- B: 数値・色・真偽値・enum・Graph座標の厳格チェック追加とエラーメッセージ整備で1〜2日（`Read*` ヘルパー全部に手を入れるため件数は多いが、パターンは機械的な繰り返し）。既存4スキンの回帰確認を含む
- C: `ApplyMode` への try/except 追加自体は半日未満の小規模変更。ただし「意図的に壊した layout.cfg／画像で起動・モード切替の両方を試す」実機検証に別途時間が必要
- 全体見積り: 2〜3日＋実機検証

## 3. 未使用アセットの削除

`assets/` 以下に、どの `layout.cfg` からも参照されていない画像ファイルがある。全 `layout.cfg` の `Bg=`/`File=`/`Font=`/`Off=`/`On=` 参照とリポジトリ全体（ソース・docs・packaging）を突き合わせて確認した結果、以下が未参照:

| ファイル | 備考 |
|---|---|
| `assets/original/Original_Banner.png` | 参照無し |
| `assets/original/Original_Font.png` | `original/layout.cfg` に `[Mode] Font=` キー自体が無い（Original は数値readout非使用） |
| `assets/original/Original_LedYellow.png` | Original の LED は Green/Red のみ使用、Yellow は未使用 |
| `assets/crystal/Crystal_Banner.bmp` | 参照無し |
| `assets/crystal/Crystal_CPU_Level_6.bmp` | `[Cpu]` は `Crystal_CPU_Level.bmp`（Frames=32）を使用。こちらは旧コマ数違いの残骸と見られる |
| `assets/crystal/Crystal_Memory_10.bmp` | `[Mem]` は `Crystal_Memory.bmp`（Frames=32）を使用。同上 |

- `assets/metalic/` は全ファイルが `layout.cfg` から参照済み（未使用なし）
- `assets/infobar/ImageResource/*.xcf`（GIMP 編集用ソース）は実行時に読み込まれる対象ではないが、InfoBar 用画像の編集元として意図的に残されている可能性があり、上記 6 件とは性質が違う。削除するかは別途確認してから判断する
- ライセンス面の懸念は無い: `assets/` 以下の著作権は SoRaMiMi（現開発者本人）に帰属し、旧版と同一（[README.md:72](../README.md#L72)）。第三者の権利は絡まない

見積り: 半日未満（`git rm` と各 `.gitignore`/参照有無の最終確認のみ）。

## 4. BMP → PNG 変換

`assets/crystal/` と `assets/metalic/` の `.bmp` 画像を可逆変換で `.png` に置き換える（`assets/original/` は既に PNG）。

### 技術的な裏付け

- 画像ローダー `TAssetStore.LoadGraphic`（[uAssetStore.pas:36-63](../src/view/uAssetStore.pas#L36-L63)）は拡張子で分岐: `.png` は `TPngImage`、それ以外は `TBitmap.LoadFromFile` で読み込み、どちらも最終的に `pf24bit` へ正規化される。**PNG は既に一級のフォーマットとして扱われており、コード変更なしで拡張子を変えるだけで読み込める**
- 置き換え対象は `layout.cfg` の `Bg=`/`File=`/`Font=` に書かれたファイル名のみ。項目3で削除予定の `Crystal_Banner.bmp`/`Crystal_CPU_Level_6.bmp`/`Crystal_Memory_10.bmp` は未参照なので変換せず削除で処理し、変換対象から除く
- **色キー透過の精度に注意**: Metalic は `Cpu`/`Mem`/`Swap`/`DiskRead`/`DiskWrite`/`DiskRW`/`NetIn`/`NetOut`/`NetTotal`/`Ping` の全パーツが `MaskColor=#000000` によるパーツ単位の色キー透過を使っている（[metalic/layout.cfg:44](../assets/metalic/layout.cfg#L44) 等）。変換時に色空間変換やアンチエイリアス・ICC プロファイル埋め込みが起きると `#000000` の一致判定がずれて透過が壊れるため、**可逆・無劣化（ピクセル値をそのまま保持）の変換**が必須。Crystal は `[Mode] MaskColor=#000000`（ウィンドウ形状の透過用、`Crystal_Base.bmp` の背景色）のみが対象で、パーツ単位の `MaskColor` は使っていない
- ファイルサイズ削減は副次効果（例: `Metalic_Base.bmp` 18,488 bytes、非圧縮 BMP が大半）

見積り: 半日程度（可逆変換の実行＋ `layout.cfg` のファイル名更新＋実機での透過崩れ目視確認）。

## 5. 新スキン: アナログ VU メーター

新しい表示モード（スキン）として、往年の VU メーター（可動コイル式アナログメーター）風のデザインを追加する。同じ意匠のメーターを横に並べ、**コンパクトモードでは CPU/MEM/DiskIO/NetIO の 4 本**、**フルモードでは CPU/MEM/SWP/DiskR/DiskW/NetIn/NetOut の 7 本**に分けて表示する。Disk・Net の Read/Write（In/Out）合成パイプラインの追加は前提として確定。

### 現状の確認結果

- 表示モードは `assets/<id>/layout.cfg` を置くだけで自動登録され（[assets/LAYOUT.md:3](../assets/LAYOUT.md#L3)）、Delphi 側のコード追加は不要
- メーター描画は完全にスプライトストリップ方式: `[Ballistic]` の `vu` プロファイルは「コマ数多めの針」向けに既に用意されている（[assets/LAYOUT.md:74-80](../assets/LAYOUT.md#L74-L80)）。値 0..1 を `TMeterRenderer.StripFrame`（[uMeterRenderer.pas:54-63](../src/view/uMeterRenderer.pas#L54-L63)）でストリップのコマ番号に変換し `BitBlt`/`TransparentBlt` するだけ（[uMeterRenderer.pas:134-161](../src/view/uMeterRenderer.pas#L134-L161)）。**針の回転描画はエンジン側に無く、あらかじめ角度違いで描いたコマを並べた縦ストリップ画像を使う**設計。つまり針そのものの見た目は素材（何コマ用意し各コマにどの角度の針を描くか）で決まり、コマ割り当てのコア描画コードは変更不要
- CPU / MEM / SWP は既存パーツ（`Cpu` / `Mem` / `Swap`）でそのまま対応可。DiskIO / NetIO は現状 **Read/Write（In/Out）が別パーツ**（`DiskReadMeter`/`DiskWriteMeter`、`NetInMeter`/`NetOutMeter`、[uMeterRenderer.pas:213-216](../src/view/uMeterRenderer.pas#L213-L216)）で、ディスク・ネットそれぞれを 1 本に合成した「DiskIO」「NetIO」という単一メーター値は存在しない

### 技術的な課題（要設計・コア変更が必須）

1. **DiskIO / NetIO 合成値の新設**: `TDisplayState`（[uMetricsTypes.pas:89-112](../src/metrics/uMetricsTypes.pas#L89-L112)）に `DiskRead`/`DiskWrite`/`NetIn`/`NetOut` はあるが合成フィールドが無い。`TDisplayPipeline` の正規化・バリスティック追従処理（[uDisplayPipeline.pas:242-309](../src/metrics/uDisplayPipeline.pas#L242-L309)）は Disk/Net の4チャンネルそれぞれに正規化値・追従方向状態（`FDirDiskRead` 等）を持つ構造なので、`DiskIO`/`NetIO` も同型の追加チャンネルとして機械的に増設できる。合成式（`Max(Read,Write)` か合算か）は未決定
2. **コンパクト／フルで異なるメーター構成という要求はエンジンに無い**: `[ModeFull]` は現状 Width/Height/Bg/Transparent/MaskColor/Font/Graph のみを上書きし、メーターの各パーツ（`Cpu`/`DiskReadMeter`等のスプライト定義）は `AMeta.FullLayout := AMeta.Layout`（[uSkinLoader.pas:356](../src/view/uSkinLoader.pas#L356)）でコンパクト側から**丸ごとコピー**され、パーツ単位でコンパクト／フルを出し分ける仕組みが存在しない。「コンパクトは合成4本、フルは分解7本」を実現するには、パーツごとに表示対象（コンパクトのみ／フルのみ／両方）を指定できる新しい layout.cfg キー（例: 各パーツ節に `ShowInCompact`/`ShowInFull`）と、それを判定する `AIsFull` 相当のフラグを `TMeterRenderer.DrawMeters`/`Fingerprint`（[uMeterRenderer.pas:39-46](../src/view/uMeterRenderer.pas#L39-L46)）の呼び出し経路に通す変更が要る。これは既存3スキンの「フルはコンパクトの表示に加えて下にグラフが増えるだけ」という前提を破る初めてのケースで、他スキンの挙動に影響しないことの確認が必要
3. 横一列に 4〜7 個の円形メーターを並べるには `[Mode] Width`／`[ModeFull] Width` を既存3スキンより横長に取る必要がある

### 素材制作について

私（Claude）は画像生成ツールを持たないが、スクリプト（Python/Pillow や GDI+ 経由の描画コード）で文字盤の目盛り・スケールと、角度違いの針を並べた縦ストリップ画像を機械生成することはできる。3.1.1 のトレイ LED（[docs/PLANNED-3.1.1.md:11](../docs/PLANNED-3.1.1.md#L11)）と同じ考え方で、まずは placeholder 素材で `layout.cfg` の配線・表示を通し、本番の質感（クリーム色の文字盤、クロムベゼル、ガラス反射等）は別途、実素材（イラスト制作や権利確認済みの既存素材）に差し替える方針が妥当。AI 生成画像を本番のスキン素材として同梱する場合は著作権・利用条件の確認が要る。

見積り: 未検証。DiskIO/NetIO 合成パイプライン追加＋コンパクト／フルのパーツ出し分け機構（layout.cfg 拡張＋レンダラー改修）が新規のコア変更として先行し、それに layout.cfg 配線＋ placeholder 素材制作が乗る。本番素材の質次第でさらに変動する。
