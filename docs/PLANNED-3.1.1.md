# 3.1.1 予定（未実装）

公開ドキュメント（`public_docs/`）には予定している内容は書かない。実装が入り、利用者に見えるようになってから CHANGELOG / USAGE / NOTES / INSTALL（JA+EN）へ「実装済み」として書く。

3.1.1 のスコープは次の 6 項目。3.1.1 で扱わない機能アイデアは `docs/PLANNED-3.2.0.md` を参照。

### 着手順・運用メモ

- 着手順: **4 → 1 → 2 → 6 → 5 → 3**（リスクの低い項目から）。4（ディスクレイテンシ）で作業フローを確立し、1（Store判定）・2（アイコン）・6（雑多な動作改修）の小規模改修で慣らしてから、5（Tracert）・3（タスクトレイ）の大物に進む
- ビルド確認: この開発機の Delphi は **Community Edition** で CLI ビルド不可、RAD Studio IDE も常時起動はしていない。各項目の実装が終わるたびに、ユーザーが IDE で Win64 Release をビルドして確認する（`/code-review` はコードレビューであり、コンパイル成否の保証にはならないため）
- タスクトレイ用 LED アイコン（項目 3）: 本番素材ができるまでは、既存モード別 LED 色を元にした単色円アイコンをスクリプトで機械生成したプレースホルダーで進める。詳細は項目 3 内に記載

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

つまり **判定を `FSettings.UpdateEnabled` の参照 3 箇所に効かせれば、GitHub 確認・トレイ通知・メニュー項目の 3 つは自動的に止まる。** 残るのはオプション画面のチェックボックスを隠すことだけ。

**実装済み**:

1. 新規ユニット `src/uPackaging.pas` を追加し、`function IsStorePackage: Boolean;` を実装した
   - `GetCurrentPackageFullName`（`kernel32.dll`、Windows 8+、一般権限）を `external` 宣言
   - バッファ長 0 で 1 回目を呼び、戻り値が `ERROR_INSUFFICIENT_BUFFER`（122）ならパッケージ済み（True）、それ以外（`APPMODEL_ERROR_NO_PACKAGE`=15700 を含む）は非パッケージ（False）と判定する。初回呼び出し結果をユニット内キャッシュ変数に保持し、以降は再計算しない
   - 既存の `uUpdateCheck.CDebugForceNewerRelease` と同じ流儀の `CDebugForceStorePackage: Boolean = False` を用意（リリース前に False であることを確認）
2. `src/uMainForm.pas` に `function TMainForm.UpdateCheckEnabled: Boolean;`（[uMainForm.pas:896-902](../src/uMainForm.pas#L896-L902)）を追加し、`(FSettings <> nil) and FSettings.UpdateEnabled and not IsStorePackage` を返す。**`FSettings.UpdateEnabled` 自体は書き換えない**（`FormCreate` 内で複数回走る `PersistSettings` により ini へ書き戻ってしまい、将来同じ ini を非 Store 環境で使い回した際に影響が残るため）。既存の5箇所の参照（`UpdateDelayTick`／`SyncUpdateMenu`／`ApplyUpdateCheckResult`／`FormCreate`／`miOptionsClick`）をすべてこのヘルパー経由に統一した
3. `src/uOptionsForm.pas` の `LoadFromSettings` で `IsStorePackage` が True のとき `ChkUpdateCheck.Visible := False` にし（後続コントロールは詰めず空欄のまま）、設定保存時の処理でも `IsStorePackage` のときは `ChkUpdateCheck.Checked` を `FSettings.UpdateEnabled` へ書き戻さない（隠れたチェックボックスの状態で保存済み設定を汚さないため）
4. 手動確認（未実施・ユーザー側で実施予定）: `CDebugForceStorePackage` を一時的に True にしてビルドし、(a) 起動直後に GitHub へのリクエストが飛ばないこと、(b) トレイ通知が出ないこと、(c) 右クリックメニューに更新項目が出ないこと、(d) オプション画面にチェックボックスが出ないこと、の 4 点を確認してから False に戻す
5. 最終的に実機の MSIX（Store 提出用ビルドまたはサイドロード）でも同じ 4 点を確認する

見積り: 半日程度。

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
- `packaging/msix/PackageAssets/*.png`（Square150x150Logo / Square44x44Logo / StoreLogo / Wide310x150Logo）は目視確認済み。`packaging/msix/masters/icon.png` と同一デザインで、正しく作成されている。**再生成不要**
- ico 変換ツール: 環境に ImageMagick は無いが、Python 3.12 + Pillow（`pip install pillow` 一回）で 16/32/48/256 の多重解像度 ico を生成できることを確認した。外部ツールの導入判断は不要

手順:

1. `packaging/msix/masters/icon.png`（1024×1024、不透明な正方形デザイン）から `assets/MAINICON.ico` を生成する（Python + Pillow、16/32/48/256 を個別に LANCZOS リサンプルして同梱）
2. 生成した ico で `assets/MAINICON.ico` を置き換える
3. IDE でビルドし、exe アイコン（Explorer・タスクバー・Alt+Tab）とタスクトレイアイコンを目視確認する

**実装済み**（手順1〜3）。`tools/make-portable.ps1` / `tools/make-installer.ps1` によるポータブル zip・インストーラーへの反映確認は、3.1.1 の全項目が完了した後の Win64 Release ビルド・配布物再生成時（`docs/CONTRIBUTING.md` の「リリース時」節、`docs/DESIGN.md` 15 節）にまとめて行う。項目単位では実施しない（Release ビルドはリリース直前に一度だけ行えば十分なため）。

見積り: 半日程度。「表示サイズ タスクトレイ」用の LED アイコン（項目 3）とは別素材・別作業。

## 3. 表示サイズ タスクトレイ（ディスクアクセス LED）

**コンパクト／フルに第 3 の表示サイズ「タスクトレイ」を追加する。** 選択するとメインウィンドウを画面から消し、通知領域のアイコン自体をディスクアクセス LED として動かす。素材は表示モードごとに `assets/<id>/` へ置く。

3.1.0 のトレイは「起動中の常駐表示」であり、本体の格納はしない（`docs/DESIGN.md` 8.4、`public_docs/USAGE.md`）。本機能はその方針を変える。公開文への追記は実装後。

### 実装プラン（着手順）

下の各節（利用者から見た動き〜決定事項）に技術検討済みの詳細がある。着手時は次の順で進める:

1. `DiskLED.ini` の `[View] Size=compact|full|tray` 読み書きを `uSettings.pas` に追加し、旧 `[View] Compact` はキーが無いときだけフォールバックとして読む
2. 右クリックメニューの表示サイズ選択を排他 3 択に変更する（`uMainForm.pas` のモード切替メニュー生成部）
3. メインウィンドウの非表示／復元ロジックを実装する。非表示は `Visible := False` / `ShowWindow(SW_HIDE)`（HWND は残す）。位置の記憶・復元は既存の `uWindowPlacement.pas` をそのまま使う
4. トレイサイズ用の Off/On ico 素材を `assets/<id>/TrayOff.ico` / `TrayOn.ico` として用意し、`layout.cfg` の `[Tray]` セクション読み込みを `uSkinLoader.pas`（または `uDisplayModes.pas`）に追加する。対象は Original / Crystal / Metalic / Info Bar の全モード
5. `TTrayIcon` の LED 差し替えロジックを実装する。**「表示更新頻度」節の実装方針 1〜5** に従う: トレイサイズのときだけ状態変化時に `NIM_MODIFY`（`NIF_ICON`）、HICON はモード切替・DPI 変更時に Off/On を事前生成、サンプリングは既存の表示 fps（10/15/20）に乗せる、Hint 更新とアイコン更新は分ける
6. トレイサイズ中はガジェットの `Render`/`Invalidate` をスキップする。ダッシュボードと計測タイマーは変更なしで動作継続することを確認する
7. **実機検証**（「表示更新頻度」節の実機チェックリストに従う）: Windows 10/11 × 100/150/200%、小ファイル連打コピー時の点滅、`explorer.exe` の CPU 使用率、隠れアイコン、更新バルーンとの干渉
8. 公開ドキュメント更新（「公開ドキュメント（実装後）」節のとおり USAGE/FEATURES/CHANGELOG/NOTES/`assets/LAYOUT.md`）は実装完了後に行う

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

**素材の用意（プレースホルダー方針）:**

本番の絵作りはデザイン作業のため、まず機械生成のプレースホルダーで実装を先に進める。

- 既存の各モードの活動 LED 色を基準色にする: Original は `Original_LedGreen.png` 相当の緑、Crystal は `Crystal_Green.bmp` 相当の緑、Metalic は `Metalic_LedB.bmp`（青系）を基準にする。Info Bar は活動 LED 資産が現状無いため、他モードと揃える形で仮に緑を割り当てる
- 見た目: 単なる塗りつぶし円ではなく、**筐体に埋め込まれた丸形 LED 風**にする。`packaging/msix/masters/icon.png`（アプリアイコンのマスター）がすでにこの意匠（黒いベゼル・中心のグロー・左上寄りのハイライト）なので、それと同じ視覚言語に揃える
  - 中心から縁へ向かうラジアルグラデーション（中心はやや明るい基準色、縁は暗く落とした基準色）で球面的な立体感を出す
  - 左上寄りに小さく白いハイライト（半透明の楕円、縁をぼかす）を重ね、光の反射があるように見せる
  - 円の外周に細い暗色のリング（ベゼル）を1本添え、「面に埋め込まれている」印象にする
  - Off はハイライトを弱める／消し、基準色を暗く彩度を落として無灯火に見せる。On はハイライトを保ったまま基準色を明るくする
- 生成方法: Python（Pillow、`uAppStrings`側の実装とは無関係な使い捨てスクリプト）で 256×256 を1枚描画（グラデーション・ハイライト・ベゼルを高解像度で作った方がきれいに縮小できる）し、そこから 48/32/16 へ `LANCZOS` でダウンサンプルして ico 化する。スクリプトは `tools/` 配下に置くかその場限りにするかは実装時に決める
- 本番素材に差し替える際は `assets/<id>/TrayOff.ico` / `TrayOn.ico` をファイル単位で置き換えるだけで済む（コード・`layout.cfg` の参照方法は変わらない）

### 表示更新頻度（調査。実機検証は実装時）

Microsoft は `NIM_MODIFY` の上限 Hz を書いていない。各回は explorer への IPC で、HICON を毎ティック新規作成すると GDI ハンドルを溶かす。

実測に近い手がかり:

- 本アプリのガジェットは **10 / 15（既定）/ 20 fps**。LED は即時、見た目が同じなら再描画しない
- 類似アプリ（トレイ専用の HDD LED）は既定 **UpdateInterval=30 ms（約 33 Hz）**。2026 年時点でもその説明のまま
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
- 単一起動の 2 つ目は現状ウィンドウを前面化する。トレイサイズ中も同様に前面化を試みる（後述の決定事項）
- Store 版でもトレイ LED は出す（「最優先」で止めるのは GitHub 確認だけ）

### 決定事項

- トレイアイコンの **ダブルクリック**: 直前のコンパクト／フルに戻す
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

## 4. ディスク遅延（レイテンシ）

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

## 5. Ping 時の Tracert（専用ウィンドウ表示）

Tracert は**通常の Ping サイクル（5 分間隔・自動）には連動させない**。TraceRouteResult ウィンドウを開いたとき、および同ウィンドウのボタン押下時にだけ実行する。ダッシュボードではなく、専用の「TraceRouteResult」ウィンドウに表示する。

### 仕様

- **実行タイミング**: (a) TraceRouteResult ウィンドウを開いたとき、(b) 同ウィンドウの「Ping/TraceRoute 更新」ボタン押下時、の2つのみ。定期 Ping（5 分間隔）には連動しない — 普段の Ping 動作の負荷・通信量を増やさないため
- **右クリックメニュー**: 既存の「Ping 更新」項目を撤廃し、代わりに「Ping結果表示」項目にする。選択すると TraceRouteResult ウィンドウを開く（開いた瞬間に (a) の Tracert 実行がかかる）
- **ウィンドウ**:
  - 初期サイズはオプション画面程度（実装後に微調整）
  - ユーザーがドラッグしてリサイズできる（`bsSizeable`。ダッシュボードと同様に最小サイズ制約を設ける）
  - デザインはダッシュボードに倣う（`uDashboardTheme.pas` のパレットを使い、VCL Style は使わず自前描画。ライト/ダーク対応）
- **表示内容**:
  - トレース先のホスト名と IP
  - ホップ数、トータル ms
  - 各ホップの TTL・IP・ホスト名のリスト（約 20 行表示。超えたらスクロールで閲覧可能）
  - **左下**に「Ping/TraceRoute 更新」ボタン（押すと即時 Ping と Tracert の両方を実行し直す。旧「Ping 更新」メニューの役割をここへ移す）
  - **右下**に閉じるボタン

### 実装済み

1. **ICMP 共通宣言の切り出し**: `src/metrics/uIcmpApi.pas` を新設し、`IcmpCreateFile`/`IcmpCloseHandle`/`IcmpSendEcho`（`iphlpapi.dll`）を集約した。レコード型・`IP_STATUS` 定数は RTL の `Winapi.IpExport` から取得しつつ、`uIcmpApi` 自身の名前空間へ再エクスポートしている（`Winapi.Winsock` と `Winapi.IpExport` は互いに別の `in_addr` 型を持つため、両方を同一ユニットの `uses` に並べると `IN_ADDR`/`inet_ntoa` が曖昧になる。消費側ユニットは `uIcmpApi` だけを参照すればよい設計にして回避した）
2. **`src/metrics/uTracertCollector.pas`（独立したオンデマンド実行）**
   - `TPingCollector.CurrentTarget`（新規公開メソッド）で解決済みターゲットを取得し、`TMetricsCollector.CurrentPingTarget` 経由で呼び出し側へ渡す。`uTracertCollector` は `TPingCollector` に直接依存しない（ホスト名を文字列として受け取るだけ）
   - TTL 1→30 を `IcmpSendEcho` ＋ `TIpOptionInformation.Ttl` でインクリメントしながら送信。宛先到達（`IP_SUCCESS`）で打ち切り、連続5回応答なしで打ち切る
   - **ホップは確定するたびに `OnHop` で即座に通知**（`tracert.exe` と同じく近い方から順に1行ずつ表示される）。逆引きDNS（`GetNameInfoW`）は各ホップごとに完全に非同期（fire-and-forget）で行い、トレースの進行を一切ブロックしない。解決でき次第 `OnHostName`（TTLで突合）で個別に反映する
   - 実行世代カウンタ（`FGeneration`）を持ち、ウィンドウを閉じて即座に再度開いた場合など、古い実行の逆引きDNSが後から完了しても新しい実行の結果に紛れ込まないようにガードしている
   - `TThread.Queue` に渡すクロージャがループ変数を参照キャプチャして直近の値で上書きされる問題を避けるため、通知はパラメータ渡しのヘルパー関数経由にしている
   - 参照カウント式のキャンセルトークン（`ITracertCancelToken`）を介してワーカースレッド・逆引きDNSスレッドからのコールバックを仲介し、`TTracertCollector` 自体が破棄された後に届いたコールバックは何もせず抜ける（解放済みオブジェクトへアクセスしない）。`Destructor` でトークンをキャンセル状態にする
   - Winsock の初期化（`WSAStartup`/`WSACleanup`）は実行ごとではなく `TTracertCollector` インスタンスの生存期間全体で1回だけ行う（`TPingCollector` と同じ方針）。実行終了直後にまだ動いている逆引きDNSスレッドと競合しないようにするため
   - DNS解決・ICMPハンドル生成そのものが失敗した場合は `TTracertResult.Failed` を立てて区別する（正常に到達不能だった場合の `Completed=False` とは別扱い）
3. **新規フォーム `src/uTraceRouteForm.pas` / `.dfm`**（制御は全て `FormCreate` でコード生成。Dashboard と同じ流儀）
   - `BorderStyle = bsSizeable`、`Constraints.MinWidth/MinHeight` 設定
   - ヘッダー（宛先ホスト名・IP、ホップ数、合計時間、計測日時）は `uDashboardTheme` パレットで自前描画
   - ホップ一覧は `TListView`（`vsReport`）を採用。ただし列見出し行とグリッド線・外枠はOS標準の固定色でテーマに追従しないため、列見出しは非表示にして自前描画の行に置き換え、外枠は1pxの`TPanel`で代替、グリッド線は無効化した。リスト本体は `SetWindowTheme(Handle, '', '')` でExplorerビジュアルスタイルを無効化しパレット色を強制適用
   - `WM_SETTINGCHANGE`（`ImmersiveColorSet`）ハンドラでWindowsのテーマ切替にリアルタイム追従（Dashboardと同じ仕組み）。タイトルバーのダークモード対応は `CreateWnd` で再適用
   - `FormShow` で1回キック。左下「Ping/経路 更新」ボタン、右下閉じるボタン。閉じるときは `caHide` でウィンドウを破棄せず、再度開いたときに `FormShow` が再度キックする
4. **開き方・既存メニューの置き換え**: `uMainForm.pas` の `miPing`（`menu.ping`）のキャプションを「Ping結果表示」に差し替え、クリックハンドラを `ShowTraceRouteForm`（`TTraceRouteForm` を無ければ生成して表示）に変更した
5. **文字列**: `trace.*` 系の新規 id を JA/EN で追加

### 設計メモ

- 通常の Ping サイクルに連動させない設計にしたことで、Tracert（最大 30 ホップ＋ホップごとの逆引き DNS）による通信量・負荷は「ウィンドウを開いたとき」「更新ボタンを押したとき」だけに限定される。普段の待機中は追加の通信を発生させない
- リスト部は `TListView` を採用したが、見出し行・外枠・グリッド線の3箇所がOS標準の固定色描画でテーマに追従しないことが実装中に判明し、それぞれ自前描画・`TPanel`枠・非表示という個別の回避策で対応した

見積り: 3〜4 日（Tracert 用ワーカーの新規実装＋逆引き DNS＋新規ウィンドウの UI 一式のため、当初のダッシュボード内表示案よりやや増加）。

## 6. 雑多な動作改修

**マウスオーバー時のホバーポップアップが画面外・モニター境界にはみ出す** ／ **解像度変更などで本体ウィンドウが画面外・タスクバー下に隠れて操作不能になる** ／ **サブモニターに置いた本体ウィンドウが、終了して再起動するとメインモニターへ移動してしまう** の3件を修正する。

### 6-1. ホバーポップアップの表示位置

- **原因確認済み**: `src/uHoverTip.pas` の `THoverTip.ShowAtCursor` はカーソル座標に固定オフセット（`Y+18`）を足しただけの位置へ `TTM_TRACKPOSITION` で直接出しており、画面端・モニター境界のクランプが無い。`TTF_ABSOLUTE` 指定のため OS 側の自動調整もかからない
- **実装済み**: `TTM_GETBUBBLESIZE` は非バルーン形式の追跡ツールチップでは表示前に信頼できるサイズを返さないことが実機検証で判明したため、代わりに一旦 `TTM_TRACKPOSITION`＋`TTM_TRACKACTIVATE` で通常どおり表示してから `GetWindowRect` で実際のウィンドウ矩形を取得し、`src/uWindowPlacement.pas` に新規追加した公開関数 `ClampRectToWindowMonitor`（既存の `ConstrainAndSnapRect` と同じ `ConstrainToWorkArea` ロジックを再利用しつつ、モニター判定を矩形自身（`MonitorFromRect`）ではなく**本体ウィンドウ**（`MonitorFromWindow(FOwner, ...)`）基準にしたもの。矩形が境界をまたぐ場合に本体と別モニターへクランプされるのを防ぐ）でモニター作業領域内へクランプ、はみ出す場合のみ `TTM_TRACKPOSITION` を再送して補正する（[uHoverTip.pas:99-140](../src/uHoverTip.pas#L99-L140)）。さらに、クランプ後の矩形がカーソル自身を覆ってしまう場合（主に下端でのクランプ時）はホバー表示/非表示が点滅するループに陥るため、`PtInRect` で検出してカーソルの上側へ反転配置してから再クランプする

### 6-2. 画面外に隠れて操作不能になる問題への対策

- **確認できたこと**: 起動時（`TMainForm.FormCreate`）には既に `ApplyWindowBounds` が `ConstrainAndSnapRect` でモニター作業領域内へクランプしており、**次回起動時は自動復旧する**
- **残っている穴**: 起動したまま解像度・モニター構成を変えた場合に再クランプする仕組みが無い（`WM_DISPLAYCHANGE` ハンドラが本体に無い）。本体はボーダーレス・タスクバーボタン無しのため、OS標準の「ウィンドウを画面内に戻す」操作も使えない
- **実装済み**:
  1. `TMainForm.WMDisplayChange`（[uMainForm.pas:1130-1138](../src/uMainForm.pas#L1130-L1138)）を追加し、`WM_DISPLAYCHANGE` 受信時に `ApplyWindowBounds` を呼んで再クランプする
  2. 右クリックメニューに「位置をリセット」項目（`menu.reset_position`）を追加し、`miResetPositionClick`（[uMainForm.pas:887-894](../src/uMainForm.pas#L887-L894)）で `ApplyWindowBounds` → `PersistSettings` → `BringWindowForward` を手動で呼べるようにした。タスクトレイのアイコンは本体が画面外でも常に操作できるので、確実な復旧手段になる

### 6-3. サブモニターに置いた本体ウィンドウが再起動でメインモニターへ移動する

- **再現条件確認済み**: 本体ウィンドウをサブモニター、ダッシュボードをメインモニターに置いた状態で終了→起動すると、本体がダッシュボード側のモニターへ引き寄せられる（本体とダッシュボードが同じモニターなら発生しない）
- **原因確認済み**（VCL ソース `Vcl.Forms.pas` を直接確認）: `TCustomForm.SetVisible`（`Vcl.Forms.pas:6241-6260`）は `Visible` が False→True になる瞬間、`inherited Visible := Value` を実行する**前**に `SetWindowToMonitor`（`Vcl.Forms.pas:7510-7571`）を呼ぶ。この関数は `DefaultMonitor` プロパティ（既定値 `dmActiveForm`。`TMainForm` は明示指定していないため既定のまま）が `dmDesktop` でない限り動作し、「アクティブなフォームが乗っているモニター」（`Screen.ActiveCustomForm.Monitor`）と「このウィンドウ自身が乗っているモニター」が異なる場合、**`Position = poDesigned` であっても関係なく**ウィンドウを強制的に前者のモニターへ再配置する（`FPosition = poScreenCenter` / `poMainFormCenter` のときだけ別処理になり、それ以外は全部この再配置分岐に入る）。`TMainForm.FormCreate` 内の `ShowDashboard`（[uMainForm.pas:309-310](../src/uMainForm.pas#L309-L310)、`FSettings.DashboardOpen` が真の場合に呼ばれる）は本体が可視化される前に実行されるため、ダッシュボードが先に「アクティブなフォーム」になり、そのモニターへ本体が引き寄せられる。`.dpr` の `Application.Run`（[DiskLED.dpr:61](../DiskLED.dpr#L61)）が呼ぶ `FMainForm.Visible := True` がこのトリガーであり、`TMainForm.FormCreate` の外（`Application.CreateForm` が返った後）で発生するため、`FormCreate` 内の処理順序をどう変えても防げない
- **実装済み**: `TMainForm.FormCreate` の `Position := poDesigned;` の直後に `DefaultMonitor := dmDesktop;` を追加した（[uMainForm.pas:242-249](../src/uMainForm.pas#L242-L249)）。`SetWindowToMonitor` の冒頭ガード（`if (FDefaultMonitor <> dmDesktop) and ...`）によりこの関数自体が無効化され、VCL による自動モニター追従は発生しなくなる。位置管理は既存の `ConstrainAndSnapRect`（`uWindowPlacement.pas`）に一本化される
- あわせて、ini の保存位置を復元する `SetBounds(FSettings.WindowX, FSettings.WindowY, ...)` を `ApplySettingsToUi` および `ApplyMode(FSettings.Mode)` より前に実行する順序にした（[uMainForm.pas:285-294](../src/uMainForm.pas#L285-L294)）。`TMainForm.CreateParams`（[uMainForm.pas:168-181](../src/uMainForm.pas#L168-L181)）は VCL 標準どおり「現在の Left/Top を使う」動作のままで、座標の明示注入はしていない（HWND 再生成のたびに保存済み座標へ巻き戻ると、その時点の実位置と食い違う恐れがあるため）

### 6-4. 項目5（Tracert）の `/code-review ultra` で見つかった軽微な改善事項（未着手）

主題（Tracert機能そのもの）とは直接関係しない、コード品質・堅牢性の改善提案。

- `TPingCollector.CurrentTarget`（`uPingCollector.pas`）は起動直後・自動ゲートウェイ有効時、初回Ping完了前は設定ホストを返す（ゲートウェイではない）。実害は数秒待てば解消する程度
- `TTracertCollector.RunAsync`（`uTracertCollector.pas`）は `TThread.CreateAnonymousThread(...).Start` が例外を投げた場合 `FRunning` が戻らず、以後そのインスタンスで二度と実行できなくなる
- `uTracertCollector.pas` の `ResolveIPv4` が `uPingCollector.pas` の同名関数とほぼ同一のコピーになっている。本来は共通ユニット `uIcmpApi.pas` に置くべき
- `uTraceRouteForm.pas` の `CreateWnd` オーバーライド＋`WM_SETTINGCHANGE`（ダークモード追従）が `uDashboardForm.pas` と全く同じ内容で重複している。共通化の余地あり
- `menu.ping` の文字列ID・`miPingClick` ハンドラ名が「Ping更新」時代のまま残っており、「Ping結果表示（ウィンドウを開く）」という現在の役割と合っていない
- `uTracertCollector.pas` の `StartReverseLookup` はホップごとに新規スレッドを生成する（最大30本）。1つのワーカー/プールで捌く設計の方が効率的（実用上の速度差は小さい）

見積り: 半日程度（3件とも既存の `uWindowPlacement.pas` ロジックを再利用する、または呼び出し順序の変更のみで小規模）。
