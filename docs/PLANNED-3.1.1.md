# 3.1.1 予定（未実装）

公開ドキュメント（`public_docs/`）には予定している内容は書かない。実装が入り、利用者に見えるようになってから CHANGELOG / USAGE / NOTES / INSTALL（JA+EN）へ「実装済み」として書く。

3.1.1 のスコープは 1〜6 の 6 項目に確定（2026-09-05）。うち 3 は「追加しない」という決定のみで実装プランはない。3.1.1 で見送った他の機能アイデアは `docs/PLANNED-3.2.0.md` へ移動した。

### 着手順・運用メモ（2026-09-05）

- 着手順: **5 → 1 → 2 → 6 → 4**（リスクの低い項目から）。5（ディスクレイテンシ）で作業フローを確立し、1（Store判定）・2（アイコン）の小規模改修で慣らしてから、6（Tracert）・4（タスクトレイ）の大物に進む
- ビルド確認: この開発機の Delphi は **Community Edition** で CLI ビルド不可、RAD Studio IDE も常時起動はしていない。各項目の実装が終わるたびに、ユーザーが IDE で Win64 Release をビルドして確認する（`/code-review` はコードレビューであり、コンパイル成否の保証にはならないため）
- タスクトレイ用 LED アイコン（項目 4）: 本番素材ができるまでは、既存モード別 LED 色を元にした単色円アイコンをスクリプトで機械生成したプレースホルダーで進める。詳細は項目 4 内に記載

## 1. 最優先

**Microsoft Store 版では GitHub の版確認も Release ページへの誘導もしない。**

- 起動時の GitHub Releases Latest 確認（`uUpdateCheck`）をしない
- トレイ通知を出さない
- 右クリックの「新しい DiskLED 3.x.x の情報を見る」を出さない
- オプションの「起動時に新しい版を確認する」を出さない（無効化する）

インストーラー／ポータブルは 3.1.0 どおり GitHub Latest を使う。

判定は実行時にパッケージ化されているか（例: `GetCurrentPackageFullName` が成功）を見る。コンパイル定数だけの分岐にしない（同じ exe を MSIX に梱包するため）。

### 実装プラン

現行コードを確認した結果、更新チェックまわりは既に `FSettings.UpdateEnabled` 1 箇所のフラグに集約されている（`src/uMainForm.pas`）:

- `TMainForm.UpdateDelayTick`（[uMainForm.pas:919](../src/uMainForm.pas#L919)）: `not FSettings.UpdateEnabled` なら GitHub へのフェッチ自体を行わず即 Exit
- `TMainForm.SyncUpdateMenu`（[uMainForm.pas:881](../src/uMainForm.pas#L881)）: 同フラグが False ならメニュー項目 `FMiUpdate`（「新しい DiskLED 3.x.x の情報を見る」）を非表示
- `TMainForm.ApplyUpdateCheckResult`（[uMainForm.pas:952](../src/uMainForm.pas#L952)）: 同フラグが False ならバルーン通知（`ShowUpdateBalloon`）に進まない

つまり **`FSettings.UpdateEnabled` を Store 版で常に False にすれば、GitHub 確認・トレイ通知・メニュー項目の 3 つは自動的に止まる。** 残るのはオプション画面のチェックボックスを隠すことだけ。

1. 新規ユニット `src/uPackaging.pas` を追加し、`function IsStorePackage: Boolean;` を実装する
   - `GetCurrentPackageFullName`（`kernel32.dll`、Windows 8+、一般権限）を `external` 宣言する
     ```pascal
     function GetCurrentPackageFullName(var packageFullNameLength: UINT32;
       packageFullName: PWideChar): LongInt; stdcall;
       external 'kernel32.dll' name 'GetCurrentPackageFullName';
     ```
   - バッファ長 0 で 1 回目を呼び、戻り値が `APPMODEL_ERROR_NO_PACKAGE`（15700）なら非パッケージ（False）、`ERROR_INSUFFICIENT_BUFFER`（122）ならパッケージ済み（True）と判定する。プロセス起動後に変わる値ではないため、初回呼び出し結果をユニット内キャッシュ変数に保持して以降は再計算しない
   - 既存の `uUpdateCheck.CDebugForceNewerRelease` と同じ流儀で、開発機で Store 分岐を手動確認するための `CDebugForceStorePackage: Boolean = False` を用意しておく（リリース前に False であることを確認）
2. `src/uMainForm.pas` の設定読み込み直後（`FSettings := TSettings.Create` 系の初期化箇所、`ScheduleUpdateCheck` が最初に呼ばれる `FormCreate` より前）に、`if IsStorePackage then FSettings.UpdateEnabled := False;` を追加する。**ini には書き戻さない**（メモリ上の値だけ上書きし、`PersistSettings` で保存しない。将来同じ ini を非 Store 環境で使い回しても影響しないようにする）
3. `src/uOptionsForm.pas` の `LoadFromSettings`（チェックボックス初期化箇所）で、`IsStorePackage` が True のとき `ChkUpdateCheck.Visible := False` にする。可視領域が詰まるよう、既存のカードレイアウト（他チェックボックスの `Top` 位置）に合わせて後続コントロールを詰めるか、空欄のまま残すかは実装時に画面を見て決める
4. 手動確認: `CDebugForceStorePackage` を一時的に True にしてビルドし、(a) 起動直後に GitHub へのリクエストが飛ばないこと（ネットワーク越しに確認するか、`TryFetchLatestRelease` にブレークポイント）、(b) トレイ通知が出ないこと、(c) 右クリックメニューに更新項目が出ないこと、(d) オプション画面にチェックボックスが出ないこと、の 4 点を確認してから False に戻す
5. 最終的に実機の MSIX（Store 提出用ビルドまたはサイドロード）でも同じ 4 点を確認する

見積り: 半日程度（新規ユニットは小さく、呼び出し側の変更点も 2 箇所のみ）。

## 2. アプリアイコン

**`packaging/msix/masters/icon.png` を 3.1.1 以降の正式なアプリアイコンとする。**

- トレイ常駐用のアプリアイコン（コンパクト／フル時）・exe（`DiskLED.dproj` の MainIcon / `assets/MAINICON.ico`）・Store 用 `PackageAssets` ロゴは、この PNG を元にする
- 3.1.0 の `MAINICON.ico` はそのまま使わない
- 実装時に ico / 各サイズ PNG へ落として差し替える（手順の詳細は実装時）
- 下の「表示サイズ タスクトレイ」で使うディスク LED 用アイコンは **表示モードごとの別素材**。`MAINICON.ico` とは共用しない

### 実装プラン

コード変更は不要（アセット差し替えとビルドのみ）と確認できた:

- `DiskLED.dproj` は既に `Icon_MainIcon` に `assets\MAINICON.ico` を指している（[DiskLED.dproj:64](../DiskLED.dproj#L64)）。ファイルの中身を差し替えれば IDE の Win64 Release ビルドがそのまま新アイコンを埋め込む
- `docs/DESIGN.md` 8.4 節より、タスクトレイ（コンパクト／フル時）も同じ `assets/MAINICON.ico` を表示している。つまり **`MAINICON.ico` を 1 回差し替えるだけで exe アイコンとトレイアイコンの両方に反映される**
- `packaging/msix/PackageAssets/*.png`（Square150x150Logo / Square44x44Logo / StoreLogo / Wide310x150Logo）は目視確認済み（2026-09-05）。`packaging/msix/masters/icon.png` と同一デザインで、正しく作成されている。**再生成不要**
- ico 変換ツール: 環境に ImageMagick は無いが、Python 3.12 + Pillow（`pip install pillow` 一回）で 16/32/48/256 の多重解像度 ico を生成できることを確認した。外部ツールの導入判断は不要

手順:

1. `packaging/msix/masters/icon.png`（32bit ARGB）から `assets/MAINICON.ico` を生成する（Python + Pillow、16/32/48/256 を同梱）
2. 生成した ico で `assets/MAINICON.ico` を置き換える
3. IDE で Win64 Release をビルドし、exe アイコン（Explorer・タスクバー・Alt+Tab）とタスクトレイアイコンをライト／ダーク双方のタスクバーで目視確認する
4. `tools/make-portable.ps1` / `tools/make-installer.ps1` で配布物を再生成し、ポータブル zip・インストーラー双方でアイコンが更新されていることを確認する（`docs/DESIGN.md` 15 節）

見積り: 半日程度（変換とライト/ダーク・複数 DPI での目視確認が主）。「表示サイズ タスクトレイ」用の LED アイコン（項目 4）とは別素材・別作業。

## 3. 表示モード Minimal（3.1.1 は追加しない）

**3.1.1 では表示モード `Minimal` の追加を取りやめる。**

- （3.1.1 では表示モード `Minimal` の追加を取りやめたため記載なし）

実装プランなし（不採用の記録のみ）。

## 4. 表示サイズ タスクトレイ（ディスクアクセス LED）

**コンパクト／フルに第 3 の表示サイズ「タスクトレイ」を追加する。** 選択するとメインウィンドウを画面から消し、通知領域のアイコン自体をディスクアクセス LED として動かす。素材は表示モードごとに `assets/<id>/` へ置く。

3.1.0 のトレイは「起動中の常駐表示」であり、本体の格納はしない（`docs/DESIGN.md` 8.4、`public_docs/USAGE.md`）。本機能はその方針を変える。公開文への追記は実装後。

### 実装プラン（着手順）

下の各節（利用者から見た動き〜未決）に技術検討済みの詳細がある。着手時は次の順で進める:

1. **「未決」節の 3 項目を先に決める。** ダブルクリック挙動・二重起動時の扱い・`[Tray]` 欠落時の扱いはコードの分岐設計に直結するため、実装前にブロッカーとして解消する
2. `DiskLED.ini` の `[View] Size=compact|full|tray` 読み書きを `uSettings.pas` に追加し、旧 `[View] Compact` はキーが無いときだけフォールバックとして読む
3. 右クリックメニューの表示サイズ選択を排他 3 択に変更する（`uMainForm.pas` のモード切替メニュー生成部）
4. メインウィンドウの非表示／復元ロジックを実装する。非表示は `Visible := False` / `ShowWindow(SW_HIDE)`（HWND は残す）。位置の記憶・復元は既存の `uWindowPlacement.pas` をそのまま使う
5. トレイサイズ用の Off/On ico 素材を `assets/<id>/TrayOff.ico` / `TrayOn.ico` として用意し、`layout.cfg` の `[Tray]` セクション読み込みを `uSkinLoader.pas`（または `uDisplayModes.pas`）に追加する。対象は Original / Crystal / Metalic / Info Bar の全モード
6. `TTrayIcon` の LED 差し替えロジックを実装する。**「表示更新頻度」節の実装方針 1〜5** に従う: トレイサイズのときだけ状態変化時に `NIM_MODIFY`（`NIF_ICON`）、HICON はモード切替・DPI 変更時に Off/On を事前生成、サンプリングは既存の表示 fps（10/15/20）に乗せる、Hint 更新とアイコン更新は分ける
7. トレイサイズ中はガジェットの `Render`/`Invalidate` をスキップする。ダッシュボードと計測タイマーは変更なしで動作継続することを確認する
8. **実機検証**（「表示更新頻度」節の実機チェックリストに従う）: Windows 10/11 × 100/150/200%、小ファイル連打コピー時の点滅、`explorer.exe` の CPU 使用率、隠れアイコン、更新バルーンとの干渉
9. 公開ドキュメント更新（「公開ドキュメント（実装後）」節のとおり USAGE/FEATURES/CHANGELOG/NOTES/`assets/LAYOUT.md`）は実装完了後に行う

### 利用者から見た動き（予定）

- 右クリックの表示サイズは排他選択 3 つ: **コンパクト** / **フル** / **タスクトレイ**
- フルは現状どおり、そのモードに `[ModeFull]` があるときだけ有効（Crystal / Info Bar は無効）
- タスクトレイは全モードで選べる
- **コンパクト／フル**では、トレイアイコンは **いまと同じ**。アプリアイコン（`MAINICON.ico`）を固定表示し、ディスク LED にはしない。メインウィンドウも現状どおり出す
- タスクトレイを選ぶと、画面上の **メインウィンドウを非表示** にする。プロセスは終了しない。トレイアイコンは出し続け、ディスクアクセスの **ON / OFF**（Read または Write）で絵を切り替える。Read と Write は区別しない
- コンパクトまたはフルを選ぶと、前回の位置にメインウィンドウを再表示し、トレイアイコンはアプリアイコン固定に戻す
- **トレイアイコンの右クリック**は表示サイズに関係なく、いまと同じポップアップ（本体ウィンドウの右クリックと同一メニュー・同一動作）を出す。項目の出し分けや別メニューにはしない
- ダッシュボードは独立（開いていれば出したまま。トレイメニューからも開ける）
- 計測タイマーは止めない（LED とダッシュボードのため）

### いまの実装との接点

| 項目 | 3.1.0 | 3.1.1 予定 |
|------|--------|------------|
| `TTrayIcon`（`uMainForm.SetupTray`） | 常時 `MAINICON.ico`。右クリックは本体と同じ `FPopup` | **コンパクト／フルは現状のまま**（アプリアイコン固定。LED 差し替えなし）。トレイサイズ時だけモード別 Off/On ico。`PopupMenu` は常に同じ `FPopup` |
| `DiskLED.ini` `[View] Compact` | `1`＝コンパクト、`0`＝フル | 第 3 値を足す。例: `[View] Size=compact\|full\|tray`。旧 `Compact` は無いときだけ読む |
| トレイ 右クリック | 本体と同じポップアップ | **表示サイズを問わず同じ**（メニュー内容・出し方も共通） |
| トレイ ダブルクリック | `BringWindowForward`（前面化） | トレイサイズ中は直前のコンパクト／フルに戻す（後述の決定事項）。メニュー動作とは別 |
| トレイ Hint | 本体と同じツールチップ文を約 1 秒ごと | 継続してよい。LED の `NIM_MODIFY` とは分ける |
| LED 判定 | `DiskRWOn`（Read または Write、ノイズ床 4 KiB/s、バリスティックなし） | トレイはこれだけ。Read / Write 別アイコンもネット LED も出さない |

`TAssetStore` は PNG/BMP を **24bit** に落としてキャッシュする。トレイ ico の読み込みには使わない（アルファが消える）。

### アイコン画像：推奨形式（確認結果）

`Shell_NotifyIcon` が受け取るのは **HICON** だけ。PNG/BMP をそのまま渡せない。Windows XP 以降は 32 BPP まで。

Microsoft（`NOTIFYICONDATA.hIcon`）の推奨:

- リソース（または `.ico`）に **16×16 と 32×32 の両方** を入れる。16 だけだと高 DPI で拡大されて荒れる
- 読み込みは `LoadIconMetric(..., LIM_SMALL)`（`SM_CXSMICON` に合わせる）。無ければ `LoadIconWithScaleDown` で大きい方から縮小
- 通知バルーンの大きいアイコン（`NIIF_LARGE_ICON`）は `SM_CXICON`（通常 32）。本機能の LED 本体は small

実務上の推奨（本プロジェクト）:

| 用途 | 形式 | 理由 |
|------|------|------|
| **配布・実行時** | `.ico`（1 ファイルに 16×16 と 32×32） | `LoadImage` / `TIcon.LoadFromFile` / `LoadIconMetric` がそのまま使える。Shell のネイティブ形式 |
| **色** | **32 bpp + アルファ** | タスクバーはライト／ダークがある。既存スキンのカラーキー（青・黒・赤）は縁が汚くなる |
| **作成元** | PNG 32bit ARGB（16 と 32、または 32 だけから ico 化） | 既存 `assets` の編集フローに近い。ico へは素材作成時に変換し、毎フレーム変換しない |
| 使わない | GIF アニメ、単一 16×16 だけ、8bit パレット、`TTrayIcon.Animate`＋ImageList | 後者は周期送りで、状態駆動の LED に向かない。既定間隔も 1000 ms |

高 DPI（本アプリは Per-Monitor V2）:

| 倍率の目安 | `SM_CXSMICON` の典型 |
|------------|----------------------|
| 100% | 16 |
| 125% | 20 |
| 150% | 24 |
| 200% | 32 |

20 / 24 を ico に入れてもよいが、必須ではない。32 があれば `LoadIconMetric` が縮小する。DPI 変更や explorer 再起動（`TaskbarCreated`）では ico を載せ直す。

状態は **ON / OFF の 2 枚**（Read と Write は統合。ストリップ不可。ico はサイズ用コンテナで、コマ用ではない）:

| 状態 | 条件 | 例ファイル |
|------|------|------------|
| Off | `DiskRWOn` が False | `TrayOff.ico` |
| On | `DiskRWOn` が True（Read または Write） | `TrayOn.ico` |

`layout.cfg` 案（実装時に `assets/LAYOUT.md` へ）:

```
[Tray]
Off=TrayOff.ico
On=TrayOn.ico
```

- 置き場所は `assets/<id>/`（他パーツと同じ）
- Original / Crystal / Metalic / Info Bar いずれも **専用 2 枚**。Info Bar はガジェットに活動 LED が無いが、トレイサイズでは LED になるので省略しない
- 欠けるモードはアプリアイコン固定（点灯しない）にフォールバックする（前述の決定事項）。2 枚そろえるのが本来の姿だが、無くても機能停止にはしない
- 点灯色はモードごとの素材（筐体 HDD ランプ相当の単色でよい。緑／赤の分割はしない）

**素材の用意（プレースホルダー方針、2026-09-05 決定）:**

本番の絵作りはデザイン作業のため、まず機械生成のプレースホルダーで実装を先に進める。

- 既存の各モードの活動 LED 色を基準色にする: Original は `Original_LedGreen.png` 相当の緑、Crystal は `Crystal_Green.bmp` 相当の緑、Metalic は `Metalic_LedB.bmp`（青系）を基準にする。Info Bar は活動 LED 資産が現状無いため、他モードと揃える形で仮に緑を割り当てる
- 生成方法: Python（Pillow、`uAppStrings`側の実装とは無関係な使い捨てスクリプト）で 16/32/48/256 の透過円を描き、Off は暗い/くすんだ色、On は基準色を明るく発光させた見た目にして ico 化する。スクリプトは `tools/` 配下に置くかその場限りにするかは実装時に決める
- 本番素材に差し替える際は `assets/<id>/TrayOff.ico` / `TrayOn.ico` をファイル単位で置き換えるだけで済む（コード・`layout.cfg` の参照方法は変わらない）

### 表示更新頻度（調査。実機検証は実装時）

Microsoft は `NIM_MODIFY` の上限 Hz を書いていない。各回は explorer への IPC で、HICON を毎ティック新規作成すると GDI ハンドルを溶かす。

実測に近い手がかり:

- 本アプリのガジェットは **10 / 15（既定）/ 20 fps**。LED は即時、見た目が同じなら再描画しない
- 同名の別ソフト Helge Klein *DiskLED*（トレイ専用の HDD LED）は既定 **UpdateInterval=30 ms（約 33 Hz）**。2026 年時点でもその説明のまま
- VCL `TTrayIcon.AnimateInterval` の既定は 1000 ms（常駐ランプ用途には遅すぎる）
- Windows 11 の通知領域は XAML 経由のため、10 のクラシックシェルより 1 フレーム遅れやすい、という報告はある。公式の「何 Hz まで」は無い

実装方針（検証前の仮定）:

1. **トレイサイズのときだけ**、状態が変わったとき `NIM_MODIFY`（NIF_ICON）。コンパクト／フルではアイコンを触らない（アプリアイコン固定）
2. HICON はモード切替・DPI 変更時に Off / On の 2 本を事前生成し、点灯ではハンドルを差し替えるだけ
3. サンプリングは既存の表示 fps（10/15/20）に乗せる。トレイ専用のより速いタイマーは最初から持たない
4. 連続 I/O で LED がチラつく最悪値は **表示 fps と同じ**（既定 15 Hz、最短 20 Hz）。Idle や連続 ON ではほぼ 0
5. Hint は現状どおり最大約 1 Hz。アイコン更新と同時に毎ティック Hint を書かない（`TTrayIcon` の `Refresh` は Icon も Tip も毎回送る）

**実装時に必ず実機で見ること**（この文書だけでは確定しない）:

- Windows 10 と 11、100% / 150% / 200%
- 小さなファイルの連打コピー（最悪の点滅）と、大きなファイルの連続読み（点灯したまま）
- `explorer.exe` の CPU。20 fps で数 % を超えて体感が悪いなら、トレイサイズ中だけ上限を 10 fps などに落とす案を残す
- 通知領域の「隠れているアイコン」に入ると点滅が見えない（OS の制限。ピン留めを USAGE に書くのは実装後）
- トレイサイズ中の版通知バルーンが、LED 差し替えで消えないか

結論の目安: **10〜15 Hz の状態変化は現実的。20 fps は Win11 で見てから。33 Hz は他ソフトの実績はあるが、本アプリはオプション上限の 20 を超えない。** 毎フレーム新規 ico 化はしない。

### 実装時の注意（コードはまだ書かない）

- 非表示は `Visible := False` / `ShowWindow(SW_HIDE)`。HWND は残す（`TTrayIcon` のコールバック先）。`NIS_HIDDEN` はトレイアイコン自体を隠すので使わない
- トレイサイズ中はガジェットの `Render` / `Invalidate` をスキップしてよい
- トレイサイズをやめたら、トレイアイコンをアプリアイコンへ戻し、以降は LED 差し替えをしない
- ポップアップは常に既存の `FPopup`（`FTray.PopupMenu` と本体の `PopupMenu`）。表示サイズで差し替えない
- 表示モード切替中もトレイサイズなら、新しいモードの Off / On ico に載せ替える
- 単一起動の 2 つ目は現状ウィンドウを前面化する。トレイサイズ中にどうするかは未決
- Store 版でもトレイ LED は出す（「最優先」で止めるのは GitHub 確認だけ）

### 決定事項（2026-09-05、実装前に確定）

- トレイアイコンの **ダブルクリック**: (A) 直前のコンパクト／フルに戻す。（旧案の推奨候補どおり採用）
- **2 つ目の起動**: トレイサイズ中でも通常どおり前面化を試みる＝コンパクト／フルへ復帰してウィンドウを出す（既存の「2 つ目は前面化」という挙動と一貫させ、隠れたままにしない）
- **`[Tray]` 欠落時**: エラーにせず、アプリアイコン固定（点灯なし）にフォールバックする。トレイサイズ自体は選べる（機能を丸ごと止めない）

### 公開ドキュメント（実装後）

- `USAGE.md` / `EN/USAGE.md`: メニュー 3 択、ウィンドウが消えること、コンパクト／フルではトレイはアプリアイコン固定、右クリックメニューは共通、ダブルクリック、隠れアイコン
- `FEATURES.md` / `EN/FEATURES.md`: トレイサイズ＝ディスク LED（Read/Write 統合の ON/OFF）
- `CHANGELOG.md` / `EN/CHANGELOG.md`
- `NOTES.md` が必要なら、隠れアイコン・更新 Hz の上限
- `assets/LAYOUT.md` に `[Tray]`
- いまの「トレイに出すが本体は格納しない」は削除または書き換え

---

## 5. ディスク遅延（レイテンシ）

ディスクセクションにキュー長とレイテンシを追加する。

- PDH パフォーマンスカウンター `Avg. Disk sec/Transfer` / `Current Disk Queue Length` で取得
- ダッシュボードのディスクサブセクションに数値行（現在のキュー長・平均レイテンシ ms）を追加するのが現実的
- `IOCTL_DISK_PERFORMANCE` も選択肢だが、PDH が最も素直

**検証結果:**

- **基盤は既にほぼ実装済み。** `src/metrics/uDiskCollector.pas` は `\PhysicalDisk(_Total)\Current Disk Queue Length` / `Disk Reads/sec` / `Disk Writes/sec` / `% Idle Time` を既に PDH で取得しており、`TMetricsSnapshot.DiskQueue` / `DiskReadIops` / `DiskWriteIops` / `DiskActivePct` としてダッシュボードにも表示済み（`uDashboardPainter.DrawDiskQueue`、[uDashboardForm.pas:517](../src/dashboard/uDashboardForm.pas#L517)）
- 残っているのは `\PhysicalDisk(_Total)\Avg. Disk sec/Transfer`（レイテンシ、秒単位・ms へ変換）カウンタの追加だけ
- リスクはほぼ無い（PDH カウンタが存在しない環境向けのフォールバックは既存コードの仕組みをそのまま使える）

### 実装プラン

1. **`src/metrics/uDiskCollector.pas`**
   - `private` に `FLatencyCounter: THandle`、`FLastLatencyMs: Double`、`FPdhLatencyOk: Boolean` を追加
   - `InitPdh`: `FPdhQueueOk` の判定と同様に、`PdhAddEnglishCounterW(FQuery, '\PhysicalDisk(_Total)\Avg. Disk sec/Transfer', 0, FLatencyCounter) = 0` を `FPdhLatencyOk` として追加登録する
   - `SamplePdh`: `FPdhLatencyOk` が True のとき `PdhGetFormattedCounterValue(FLatencyCounter, ...)` を取得し、値は **秒単位** なので `* 1000` して ms に変換、`< 0` を 0 にクランプして `FLastLatencyMs` に保持、`out ALatencyMs` として返す
   - `SampleIoCtl`（PDH 不可時のフォールバック）: `TDiskPerformance` の `ReadTime` / `WriteTime`（100ns 単位の累積サービス時間）は既に `SumDiskPerformance` で参照可能なので、前回との差分を `(ReadCount+WriteCount)` の差分で割って概算レイテンシを出す。分母 0（I/O が無い区間）は 0 ms 扱いにガードする
   - `Sample` の公開シグネチャに `out ALatencyMs: Double` を追加し、`SamplePdh` / `SampleIoCtl` 双方の呼び出しへ伝播する
2. **`src/metrics/uMetricsTypes.pas`**: `TMetricsSnapshot` に `DiskLatencyMs: Double;` を `DiskActivePct` の近くに追加
3. **`src/metrics/uCollector.pas`**: `TMetricsCollector.Collect` の `FDisk.Sample(...)` 呼び出しに `Result.DiskLatencyMs` を追加し、`except` ブロックのフォールバックにも `Result.DiskLatencyMs := 0;`（または `-1` で「不明」を表す既存の `DiskActivePct` の慣習に合わせる）を追加
4. **`src/dashboard/uDashboardPainter.pas`**: `DrawDiskQueue` に表示行を追加する。既存のキュー長行（`QTxt`）と同じ行に同居させる案（例 `"Queue 0.2 ・ 3.1 ms"`）が省スペースで良い。ラベル文字列は既存の `AReadLbl` / `AWriteLbl` / `AActiveLbl` と同じパラメータ渡し方式に合わせ、`ALatencyLbl` を追加する
5. **`src/uAppStrings.pas`**: 新規文字列 id（例 `dash.latency`、JA「レイテンシ」/ EN「Latency」）を追加し、呼び出し元で `S('dash.latency')` を渡す
6. **検証**: 同一マシンで Windows パフォーマンスモニター（`perfmon`）の `Avg. Disk sec/Transfer` と表示値を突き合わせて妥当性を確認。アイドル時に 0 除算で異常値が出ないこと、連続 I/O 時に値が飽和しないことを確認する

見積り: 半日〜1 日。

## 6. Ping 時の Tracert

Ping が悪化したときに、手動でトリガーして経路をダッシュボードに展開表示する。

- `IcmpSendEcho2` で TTL を変えながら投げれば自前実装可能（一般権限で動作する）
- 常時監視ではなく「Ping 悪化時に手動トリガー → 結果をダッシュボードで展開」の形が現実的
- 実行には 10〜20 秒以上かかること、途中ホップが ICMP を返さない場合があることを考慮
- 経路変化（ホップ数・中継 IP が変わった）の検知まで実装できるとさらに有用

**検証結果:**

- `src/metrics/uPingCollector.pas` に既に「専用ワーカースレッド＋ロック＋非同期送信」のパターンが実装済み（`docs/DESIGN.md` 5.5／11 節）。Tracert 用のワーカーもこれをそのまま踏襲でき、`IcmpSendEcho2` に TTL（`IP_OPTION_INFORMATION`）を指定していく実装は自前実装として現実的
- ダッシュボードにはまだ「進捗を伴う複数ホップの一覧表示」という UI が無い。ただし行数はホップ数（多くて 30 程度）に収まるため規模は小さい
- 実行時間が 10〜20 秒以上かかる点は、既存の Ping が非同期・UI 非ブロッキングである設計方針と地続きなので、同じ考え方（ワーカー完了時にスナップショット/専用状態を更新）で吸収できる

### 実装プラン

1. **ICMP 共通宣言の切り出し**: `uPingCollector.pas` に既にある `IcmpCreateFile` / `IcmpSendEcho2` 等の `external 'icmp.dll'` 宣言と関連構造体を、新規ユニット `src/metrics/uIcmpApi.pas` へ切り出す（Tracert 側と重複させないため）。`ResolveIPv4` などの共有ヘルパーも同様に検討
2. **新規ユニット `src/metrics/uTracertCollector.pas`**
   - `type TTracertHop = record Hop: Integer; Addr: string; RttMs: Double; Ok: Boolean; TimedOut: Boolean; end;`
   - 常駐コレクタではなく単発トリガー関数として実装する: `procedure RunTracert(const AHost: string; AMaxHops: Integer; const AOnHop: TProc<TTracertHop>; const AOnDone: TProc);`
   - `TThread.CreateAnonymousThread` 上で TTL を 1→`AMaxHops`（既定 30）まで incrementing しながら `IcmpSendEcho2` を送信。各ホップの結果は `TThread.Queue` で UI スレッドに戻し `AOnHop` を呼ぶ（`uMainForm.UpdateDelayTick` の `TThread.Queue` パターンを踏襲、全体完了を待たず逐次表示するため）
   - 終端判定: 宛先到達（応答が最終ホップと一致）で打ち切り。連続 N 回（例 5 回）応答なしなら諦めて打ち切るヒューリスティックを入れる（ファイアウォールで経路上が無応答のケースの対策）
3. **トリガー導線**: ダッシュボードの Ping パネル（`uDashboardPainter.DrawPingPanel`）内に小さな「Tracert」トリガー領域を描画し、`TDashboardForm` のマウスクリックハンドラでヒットテストして `RunTracert` を起動する。実行中は Ping パネル内に `dash.tracert_running`（例:「計測中… (hop N/30)」）を表示する
4. **結果表示**: `uDashboardPainter.pas` に `DrawTracertHops` を新設し、`DrawPingPanel` が使っている行描画（ホップ#・アドレス・RTT・状態色）を流用する。Ping 履歴リストの表示領域を一時的に Tracert 結果へ切り替える案を軸に、実装時に画面を見ながら確定する（新規パネル追加でレイアウトを広げる案は右カラム幅 `SideColWidth` の制約で採用しにくい）
5. **状態保持**: `TDashboardForm` に `FTracertBusy: Boolean`、`FTracertHops: TArray<TTracertHop>` を追加し、`RunTracert` のコールバックで更新・`Invalidate`
6. **文字列**: `src/uAppStrings.pas` に `dash.tracert` / `dash.tracert_running` / `dash.tracert_timeout` 等を JA/EN で追加（既存 `dash.*` / `hover.*` の id 命名規則に合わせる）
7. **決定事項（2026-09-05）**
   - トリガー UI: **ダッシュボード内クリック領域のみ**。メインウィンドウ右クリックメニューには項目を追加しない（メニューを肥大化させない。ダッシュボードを開いていないと使えない機能として割り切る）
   - 表示方法: **Ping 履歴リストと排他的に切り替える**（右カラム幅を広げない）
   - 完了後の結果保持: **ダッシュボードを閉じるまで保持**。次の Tracert 実行、または Ping 表示への切り戻しで破棄する

見積り: 2〜3 日（ワーカー実装 1 日、UI・表示切替 1〜2 日、検証込み）。
