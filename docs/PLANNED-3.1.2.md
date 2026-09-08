# 3.1.2 予定（未実装）

公開ドキュメント（`public_docs/`）には予定している内容は書かない。実装が入り、利用者に見えるようになってから CHANGELOG（JA+EN）へ「実装済み」として書く。

3.1.1 は Microsoft Store の認定へ提出済みのため、以降に見つかった変更はこの 3.1.2 に積む。

一覧は優先度（高い順）、同順位内は工数目安（小さい順）で並べている。#1 は 3.1.1 で出荷済みの機能（オプション「スタートアップに登録」）が Store 版で全く動かない実害バグのため、工数に関わらず最優先で着手する。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 | 優先度 |
|---|---|---|---|---|---|
| 1 | Store 版スタートアップ登録の修正（`windows.startupTask` 化） | 高（原因特定済み） | 中（WinRT `StartupTask` API バインディング＋マニフェスト拡張＋`IsStorePackage` 分岐） | 1〜2日＋実機 MSIX 検証 | 最優先 |
| 2 | Dashboard ウィンドウの画面外復帰 | 高（原因特定済み・実装プランも決定事項） | 低（小規模、既存関数の流用） | 半日未満 | 高 |
| 3 | assets 読み込みの堅牢化 | 高（アーキテクチャ変更は不要） | 中（既存パース関数群への横断的な変更） | 2〜3日＋実機検証 | 高 |
| 4 | 未使用アセットの削除 | 高 | 低（`git rm` のみ） | 半日未満 | 中〜高 |
| 5 | BMP → PNG 変換 | 高 | 低〜中（変換自体は容易だが色キー透過の実機確認が要る） | 半日程度 | 中 |
| 6 | 新スキン: アナログ VU メーター | 高（メーター描画自体は既存のスプライトストリップ方式で対応可） | 高（DiskIO/NetIO 合成パイプライン新設＋コンパクト／フルのパーツ出し分け機構という新エンジン機能が前提） | 未検証（コア変更＋layout.cfg拡張＋素材制作） | 中 |
| 7 | 項目 5（Tracert）実装時の軽微なコード品質改善（6 件） | 高（すべて局所的な小改修） | 低（既存コードの整理・共通化が中心） | 半日〜1 日（6 件まとめて） | 低 |
| 8 | Ping 結果表示ウィンドウの高 DPI 対応 | 高（`TDashboardForm` に前例あり） | 中（`Scaled=False` 化＋全寸法の `ScalePx` 化＋描画関数の DPI 対応＋`WM_DPICHANGED`） | 半日〜1 日＋実機検証 | 高（#2 と同じく実害の表示崩れ） |

## 1. Store 版スタートアップ登録の修正（`windows.startupTask` 化）

**Microsoft Store（MSIX）版では、オプションの「スタートアップに登録」をどう切り替えてもスタートアップ登録が全く機能しない。** 3.1.1 のスタートアップ処理調査で発覚。3.1.1 で利用者に見えている機能が Store 版で無効という実害バグのため、3.1.2 では最優先で着手する。

### 現状の確認結果

- `TStartup`（[uStartup.pas](../src/uStartup.pas)）は `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` の `DiskLED` 値を読み書きするだけで、`IsStorePackage` による分岐が無い。`SetRegistered(True)` は `'"' + ParamStr(0) + '"'` を書き込む（[uStartup.pas:51-54](../src/uStartup.pas#L51-L54)）
- MSIX コンテナ内から `HKCU\...\Run` へ書くと、書き込みは例外も戻り値エラーも出さず「成功」するが、実体はパッケージ専用の仮想レジストリ（`%LOCALAPPDATA%\Packages\SoRaMiMi.DiskLED_*\` 配下にマージされるオーバーレイ）へ隔離され、実ユーザーハイブには届かない。Windows のログオン時自動起動と `タスクマネージャ > スタートアップ` タブは実ハイブしか列挙しないため、Store 版の書き込み・削除は一切反映されない
- `IsRegistered`（[uStartup.pas:25-38](../src/uStartup.pas#L25-L38)）も同じ仮想ビューを読むため、書き込み後は `True` を返し続け、アプリ内では「登録済み」に見える。`TOptionsForm` の適用（[uOptionsForm.pas:385-393](../src/uOptionsForm.pas#L385-L393)）・`TMainForm.ApplyStartupRegistration`（[uMainForm.pas:485-493](../src/uMainForm.pas#L485-L493)、`except end` で握りつぶし）とも失敗に気づけない
- `ParamStr(0)` 依存も問題: パッケージ版の exe は `C:\Program Files\WindowsApps\SoRaMiMi.DiskLED_<version>_x64__<hash>\DiskLED.exe` で、バージョンごとにパスが変わり ACL ロックされている。生パス起動はパッケージ ID もバイパスする
- `dist/msix/layout/AppxManifest.xml` に `windows.startupTask` 拡張が無く、Store 版には有効な自動起動手段が存在しない。同マニフェストは `xmlns:desktop=...` を宣言済み（`IgnorableNamespaces="uap rescap desktop"`）のため名前空間追加は不要
- 開発機のタスクマネージャに出ている「別パスの DiskLED」エントリは、過去に非パッケージのデバッグビルド／Inno インストーラ版を実行したときに実 Run キーへ書かれた残骸。Store 版からは参照も削除もできない

### 実装プラン（方針）

**A. マニフェスト（Store 版のみ）**

- `AppxManifest.xml` の `<Application>` 直下に startup 拡張を追加する:

  ```xml
  <Extensions>
    <desktop:Extension Category="windows.startupTask" Executable="DiskLED.exe" EntryPoint="Windows.FullTrustApplication">
      <desktop:StartupTask TaskId="DiskLEDStartupTask" Enabled="false" DisplayName="DiskLED" />
    </desktop:Extension>
  </Extensions>
  ```

- `Enabled="false"` で同梱し、既定では自動起動しない（既存利用者の環境を勝手に変えない）。オン／オフはアプリ内チェックボックスから WinRT で制御する
- 新しい capability は不要。WACK / Store 認定でも `windows.startupTask` は許可された拡張
- `AppxManifest.xml` は現状どの追跡下スクリプトからも生成されていない（`dist/` は `.gitignore` 対象、`tools/` 配下に MSIX パッケージング処理は無い）。手編集での維持が正。パッケージング資産の正本手順（`docs/internal/` §MSIX、`packaging/msix/`）にこの拡張の記載を追加する

**B. `uStartup` の分岐**

- `TStartup.IsRegistered` / `SetRegistered` を `IsStorePackage`（[uPackaging.pas:34](../src/uPackaging.pas#L34)）で分岐:
  - **非パッケージ版（GitHub / Inno）**: 現行の `HKCU\...\Run` 方式を**そのまま維持**（コード無変更）
  - **Store 版**: WinRT `Windows.ApplicationModel.StartupTask` を使う
    - `StartupTask.GetAsync("DiskLEDStartupTask")` → `StartupTaskState` を `IsRegistered` に対応させる（`Enabled` → 登録済み、それ以外 → 未登録）
    - 有効化 = `RequestEnableAsync()`、無効化 = `Disable()`
    - `DisabledByUser`（ユーザーがタスクマネージャ／設定で無効化）と `DisabledByPolicy` の状態では `RequestEnableAsync` を呼んでも `State` が変わらない仕様。この場合はチェックボックスを無効化し「Windows の『スタートアップ アプリ』設定で有効化してください」の旨をラベル表示する
- WinRT を Delphi から呼ぶバインディングが工数の主因。**開発機は Delphi 13 / Studio 37.0（確認済み）。** RTL の `WinAPI.ApplicationModel.pas` には `StartupTaskState` enum（`Disabled=0` / `DisabledByUser=1` / `Enabled=2` / `DisabledByPolicy=3` / `EnabledByPolicy=4`、[Studio 37.0 WinAPI.ApplicationModel.pas:2297]）と `IAsyncOperation_1__StartupTaskState`（`RequestEnableAsync` の戻り型）が既に生成済み。ただし **`IStartupTask` / `IStartupTaskStatics` インターフェース本体は未投影** → この 2 つ（＋ `GetAsync` 用の `IAsyncOperation<StartupTask>`）を `uStartup` 内で最小限手宣言する。ファクトリ取得は `Winapi.WinRT.RoGetActivationFactory('Windows.ApplicationModel.StartupTask', IStartupTaskStatics)`。`IAsyncOperation` の待機は `WinAPI.WinRT.Utils.Await(op, AProcessMessagesProc)`（RTL 提供）。`RoInitialize` が済んでいなければ `RO_INIT_SINGLETHREADED` で 1 回。すべて `{$IF Defined(...)}` ではなく実行時 `IsStorePackage` 分岐に閉じ込め、非パッケージ版のコードパスからは WinRT を一切呼ばない（uses に WinRT ユニットを足しても、呼ばなければ非パッケージ版の挙動は不変）
- `uStartup` の公開インターフェース（`IsRegistered: Boolean` / `SetRegistered(AEnabled)`）は変更しない。呼び出し側（`uOptionsForm` / `uMainForm`）は原則そのまま

**C. `TOptionsForm` の UI**

- `ChkStartup` は Store 版でも**表示したまま機能させる**。`ChkUpdateCheck` は Store 版で `Visible := not IsStorePackage` として隠している（[uOptionsForm.pas:241-243](../src/uOptionsForm.pas#L241-L243)）が、startup は Store 版でも有効な機能なので同じ扱いにはしない
- `LoadFromSettings` の `ChkStartup.Checked := TStartup.IsRegistered or FSettings.Startup`（[uOptionsForm.pas:239](../src/uOptionsForm.pas#L239)）は分岐後の `IsRegistered` でそのまま動く
- `DisabledByUser` / `DisabledByPolicy` のときだけ `ChkStartup.Enabled := False` + 補足ラベル。新しいエラー文字列 ID を `uAppStrings.pas` に追加（例 `opt.startup_disabled_by_user`）
- 適用時の `try TStartup.SetRegistered(...) except`（[uOptionsForm.pas:385-393](../src/uOptionsForm.pas#L385-L393)）は WinRT 例外もそのまま拾える。握りつぶしている `TMainForm.ApplyStartupRegistration`（[uMainForm.pas:489-492](../src/uMainForm.pas#L489-L492)）は Store 版では `DisabledByUser` を正常系として扱うため、握りつぶしのままでよい（起動・終了時に毎回 `RequestEnableAsync` を呼ばないよう、状態が変わるときだけ呼ぶガードは入れる）

**D. 既存の残骸レジストリ**

- 旧デバッグビルド／Inno 版が実 Run キーへ残したエントリは MSIX 版からは消せない（仮想レジストリしか見えない）。Store のみのユーザー環境には元々存在しないので実害は限定的。Inno インストーラ（`installer/DiskLED.iss` の `[Registry]` + `uninsdeletevalue`）は従来どおりアンインストール時に自分の書いた値を消す

### GitHub 版（非パッケージ）への影響

- **ランタイム挙動: 変化なし。** `IsStorePackage` は GitHub 配布物（ポータブル ZIP / Inno インストーラ）では常に `False` を返す（`GetCurrentPackageFullName` が `APPMODEL_ERROR_NO_PACKAGE`）。分岐の `else` は現行の Run キーコードそのもので、WinRT のコードパスには一切入らない
- **`installer/DiskLED.iss`: 無変更。** インストーラの `[Tasks] startup` と `[Registry]` の Run キー書き込み（[installer/DiskLED.iss:47](../installer/DiskLED.iss#L47), [installer/DiskLED.iss:59](../installer/DiskLED.iss#L59)）はアプリと独立して動いており、そのまま
- **`AppxManifest.xml` の変更は MSIX パッケージ内だけ。** GitHub リリース成果物には含まれない
- **ビルド影響:** `uses` に `Winapi.WinRT` / `WinAPI.ApplicationModel` / `WinAPI.WinRT.Utils` を追加する。いずれも Delphi 13 / Studio 37.0 標準 RTL に存在（確認済み）。`IStartupTask` / `IStartupTaskStatics` の手宣言は `uStartup` の implementation 部に閉じる。実装ステップ後にユーザーが IDE ビルド（Shift+F9）で検証
- **回帰確認（非パッケージ版）:** Inno インストーラでインストール → オプションで「スタートアップに登録」ON/OFF → タスクマネージャのスタートアップタブに反映されること、再ログオンで起動すること。従来どおり動けば OK（分岐追加でここが壊れていないことの確認が主目的）

### 見積り

1〜2日＋実機 MSIX 検証（`CDebugForceStorePackage` では仮想レジストリ／WinRT 挙動を再現できないため、実際にインストールしたパッケージでタスクマネージャのスタートアップタブに反映されること・再起動で実際に起動すること・`DisabledByUser` からの復帰導線の確認が必須）。関連: 内部設計資料 §17.9（MSIX で挙動が変わる永続化パスの再検証）。

## 2. Dashboard ウィンドウの画面外復帰

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

## 3. assets 読み込みの堅牢化

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

## 4. 未使用アセットの削除

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

## 5. BMP → PNG 変換

`assets/crystal/` と `assets/metalic/` の `.bmp` 画像を可逆変換で `.png` に置き換える（`assets/original/` は既に PNG）。

### 技術的な裏付け

- 画像ローダー `TAssetStore.LoadGraphic`（[uAssetStore.pas:36-63](../src/view/uAssetStore.pas#L36-L63)）は拡張子で分岐: `.png` は `TPngImage`、それ以外は `TBitmap.LoadFromFile` で読み込み、どちらも最終的に `pf24bit` へ正規化される。**PNG は既に一級のフォーマットとして扱われており、コード変更なしで拡張子を変えるだけで読み込める**
- 置き換え対象は `layout.cfg` の `Bg=`/`File=`/`Font=` に書かれたファイル名のみ。項目4で削除予定の `Crystal_Banner.bmp`/`Crystal_CPU_Level_6.bmp`/`Crystal_Memory_10.bmp` は未参照なので変換せず削除で処理し、変換対象から除く
- **色キー透過の精度に注意**: Metalic は `Cpu`/`Mem`/`Swap`/`DiskRead`/`DiskWrite`/`DiskRW`/`NetIn`/`NetOut`/`NetTotal`/`Ping` の全パーツが `MaskColor=#000000` によるパーツ単位の色キー透過を使っている（[metalic/layout.cfg:44](../assets/metalic/layout.cfg#L44) 等）。変換時に色空間変換やアンチエイリアス・ICC プロファイル埋め込みが起きると `#000000` の一致判定がずれて透過が壊れるため、**可逆・無劣化（ピクセル値をそのまま保持）の変換**が必須。Crystal は `[Mode] MaskColor=#000000`（ウィンドウ形状の透過用、`Crystal_Base.bmp` の背景色）のみが対象で、パーツ単位の `MaskColor` は使っていない
- ファイルサイズ削減は副次効果（例: `Metalic_Base.bmp` 18,488 bytes、非圧縮 BMP が大半）

見積り: 半日程度（可逆変換の実行＋ `layout.cfg` のファイル名更新＋実機での透過崩れ目視確認）。

## 6. 新スキン: アナログ VU メーター

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

## 7. 項目 5（Tracert）実装時の軽微なコード品質改善

3.1.1 の項目 5（Tracert 専用ウィンドウ）を `/code-review ultra` に通した際に出た、主題そのものとは直接関係しない堅牢性・重複解消の指摘。3.1.1 では未着手のまま出荷したため、3.1.2 で低優先の整理項目として扱う。個々は局所的で相互依存が無いので、着手できるものから順に潰してよい。

- `TPingCollector.CurrentTarget`（`src/metrics/uPingCollector.pas`）は起動直後・自動ゲートウェイ有効時、初回 Ping 完了前は設定ホストを返す（解決済みゲートウェイではない）。TraceRouteResult ウィンドウを起動直後に開くと最初のトレース先が設定ホストになりうる。実害は数秒待てば解消する程度だが、「初回解決前」を呼び出し側が区別できるようにするか、解決完了までトレース開始を遅らせる
- `TTracertCollector.RunAsync`（`src/metrics/uTracertCollector.pas`）は `TThread.CreateAnonymousThread(...).Start` が例外を投げた場合 `FRunning` が `True` のまま戻らず、以後そのインスタンスで二度と実行できなくなる。`try/except` で `FRunning` を戻す
- `uTracertCollector.pas` の `ResolveIPv4` が `uPingCollector.pas` の同名関数とほぼ同一のコピーになっている。共通ユニット `src/metrics/uIcmpApi.pas` へ移して 1 本にする
- `uTraceRouteForm.pas` の `CreateWnd` オーバーライド＋`WM_SETTINGCHANGE`（`ImmersiveColorSet` によるダークモード追従）が `src/dashboard/uDashboardForm.pas` と実質同一内容で重複している。テーマ追従の共通ヘルパー（ミックスインユニットか基底フォーム）に括り出す
- `menu.ping` の文字列 ID・`miPingClick` ハンドラ名が「Ping 更新」時代のまま残っており、現在の役割（「Ping 結果表示」＝ウィンドウを開く）と合っていない。ID とハンドラ名を実態に合わせて改名する（`uAppStrings.pas` の ID 変更を伴うため、他の参照箇所と併せて一括で）
- `uTracertCollector.pas` の `StartReverseLookup` はホップごとに新規スレッドを生成する（最大 30 本）。1 つのワーカー／スレッドプールで捌く設計の方が効率的（実用上の速度差は小さいので優先度は最も低い）

見積り: 半日〜1 日（6 件まとめて。改名は他ユニットへの波及確認、共通化はダッシュボード側の回帰確認を含む）。

## 8. Ping 結果表示ウィンドウの高 DPI 対応

**画面拡大率 150% 等の環境で `TTraceRouteForm`（「Ping 結果表示」/ 非日本語では「View Trace Route」）の表示が崩れる。** ヘッダー 2 行の文字が重なる、リストヘッダーの列見出しが列幅からはみ出す、リスト本文の文字が周囲より小さすぎる。

### 現状の確認結果（`src/uTraceRouteForm.pas` を確認）

- **DPI 対応が一切無い。** `TDashboardForm` は `Scaled := False` ＋ `HudMetrics(dpi)`（`ScalePx` で全寸法を物理 px 化）＋ `WM_DPICHANGED` ハンドラ ＋ 描画関数での `Canvas.Font.PixelsPerInch := 96`（[09-dashboard.md](internal/09-dashboard.md) §9.3、内部資料）を持つが、`TTraceRouteForm` にはどれも無い。
- `FormCreate`（[uTraceRouteForm.pas:97-185](../src/uTraceRouteForm.pas#L97-L185)）: `Scaled` 未設定（VCL 既定の `True`）。`ClientWidth := 700` / `ClientHeight := 560` / `Constraints` / 各 `SetBounds` は生ピクセル値。
- レイアウト定数がすべて未スケール: `CListHeaderHeight=24` / `CColTtlW=48` / `CColIpW=140` / `CColHostW=280` / `CColRttW=90`（[uTraceRouteForm.pas:70-75](../src/uTraceRouteForm.pas#L70-L75)）、`CMargin=12` / `CHeaderHeight=56` / `CButtonHeight=28` / `CButtonWidth=140`（[uTraceRouteForm.pas:98-102](../src/uTraceRouteForm.pas#L98-L102)）。
- **ヘッダーの文字重なり**: `HeaderPaint`（[uTraceRouteForm.pas:243-294](../src/uTraceRouteForm.pas#L243-L294)）は `Canvas.Font.Size := 11` の行1を `TextOut(12, 6, ...)`、`Size := 9` の行2を `TextOut(12, 30, ...)` に描く。`Canvas.Font.PixelsPerInch` 未設定なのでフォームの DPI（150%＝144）でフォントが拡大され、行1（約 22px）＋ Y=6 が Y=30 の行2に食い込む。`FHeaderPaint.Height = CHeaderHeight = 56` も未スケール。
- **リストヘッダーのはみ出し**: `ListHeaderPaint`（[uTraceRouteForm.pas:211-241](../src/uTraceRouteForm.pas#L211-L241)）は `Canvas.Font.Size := 9`（拡大される）の見出しを `X := 4; TextOut(X, 4, ...); Inc(X, CColTtlW)` と**未スケールの列幅**で送るため、拡大フォントが列幅を超える。`FListHeaderPaint` 高さも `CListHeaderHeight = 24` 固定。
- **リスト本文が小さい**: `FList`（`TListView`）の列幅は `CColTtlW` 等の生値。さらに `SetWindowTheme(FList.Handle, '', '')`（[uTraceRouteForm.pas:174](../src/uTraceRouteForm.pas#L174)、Explorer ビジュアルスタイル無効化）がコントロールを DPI 非対応の既定 GUI フォントへ戻すため、周囲が 150% に拡大される中でリスト本文だけ 96dpi サイズのまま。
- `WM_DPICHANGED` ハンドラが無い（`WMSettingChange`（[uTraceRouteForm.pas:203](../src/uTraceRouteForm.pas#L203)）はテーマ追従のみ）。モニター間移動で再レイアウトされない。

### 実装プラン（`TDashboardForm` の方式を踏襲）

1. `FormCreate` で `Scaled := False`。`FDpi: Integer` フィールドと `function Dpi: Integer`（`uDpiScale.MonitorDpiForWindow(Handle)`、`WM_DPICHANGED` の LoWord 優先）を追加。
2. レイアウト定数を DIP として扱い、配置を `LayoutContent` 相当のメソッドへ集約して `uDpiScale.ScalePx(value, Dpi)` で物理化。`FormCreate` と `WM_DPICHANGED` から呼ぶ。列幅（`FList.Columns[i].Width`）・`FListHeaderPaint` 高さ・`FHeaderPaint` 高さ・ボタン寸法・マージンをすべてスケール。
3. `FList.Font` を明示的にスケール済み高さで設定（`SetWindowTheme` 後に `FList.Font.Height := -ScalePx(...)`）。テーマ無効化で失われる DPI スケールを補う。
4. `HeaderPaint` / `ListHeaderPaint`: 先頭で `Canvas.Font.PixelsPerInch := 96`（`uDashboardPainter` の `TransparentText` と同じ）を設定し、Y 座標・行間・列送り幅を `ScalePx` で物理化。
5. `WM_DPICHANGED` ハンドラを追加（`TDashboardForm.WMDpiChanged`（[uDashboardForm.pas:326](../src/dashboard/uDashboardForm.pas#L326)）と同型）: `FDpi` 更新 → 提案矩形へ移動 → `LayoutContent` → `Invalidate`。
6. 検証: Windows 10/11 × 100 / 125 / 150 / 200%。ヘッダー 2 行が重ならない、列見出しが列内に収まる、リスト本文が周囲と同じ拡大率、モニター間移動で崩れない。

見積り: 半日〜1 日（`uDashboardForm` に前例があるため）。項目 7 の「`CreateWnd`＋`WM_SETTINGCHANGE` の共通化」と同じユニットを触るので、まとめて着手すると効率的。
