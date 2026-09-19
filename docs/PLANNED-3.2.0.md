# 3.2.0 以降 検討中（未確定）

3.1.1〜3.1.2 で見送った機能アイデア。3.2.0 以降で改めて優先度を検討する。実装するか・どう組み込むかは着手時に詳細を詰める。技術的な前提はここに残すが、設計・公開文には書かない。

事前検証（現行コード `src/` を確認済み）の結果は各項目に残してある。

3.2.0 の対象は **1・2・3・4・5・6・7・8・9**。着手順は `7 → 1 → 3 → 4 → 5 → 8 → 9 → 6 → 2`。項目 7 は不具合修正のため最優先で着手する。小規模で自己完結する 1 で 3.2.0 の作業フローを慣らし、文字列基盤（3）・動的 PDH カウンタ（4）という基盤性のある項目を先に据えてから重い項目へ進む。項目 8（オプション画面の複数ページ化）は項目 5 でオプション画面の設定項目が増えた後、asset-editor（6）の前に片付ける。項目 9（Info Bar スキンの拡張）も layout.cfg の形が変わるため、asset-editor（6）が扱う最終的な layout.cfg 形式に含める必要があり、6 の直前に置く。項目 6 は 3.2.0 最大の成果物で、layout.cfg 形式が項目 5 の `[Tray]` 撤去・項目 9 の Info Bar 拡張の後に確定するため最後に置く。各項目の相対的な優先度は表の「優先度」列を参照。

項目 **10〜15** は機能項目ではなく、蓄積した変更に対する `/code-review` バッチレビューで見つかった保守性・整合性の指摘を個別タスク化したもの（優先度は低〜中）。着手順・3.2.0 出荷の必須条件には含めない。

項目 **16** はユーザー報告により判明した不具合修正で、着手順・3.2.0 出荷の必須条件には含めないが判明時点で即時対応した。

項目 **17** はユーザー報告により判明した Vintage スキンの不具合で、着手順・3.2.0 出荷の必須条件には含めない（項目 10〜15 と同様の事後対応枠）。

項目 **18** はユーザー報告により判明したダッシュボードの表示改善で、着手順・3.2.0 出荷の必須条件には含めない（項目 16〜17 と同様の事後対応枠）。

項目 **19** はオプション画面のレイアウト調整で、着手順・3.2.0 出荷の必須条件には含めない（項目 16〜18 と同様の事後対応枠）。

項目 **20** はタスクトレイ LED アイコンのデザイン調整で、着手順・3.2.0 出荷の必須条件には含めない（項目 16〜19 と同様の事後対応枠）。

項目 **24** は、リリース前の最終 `/code-review`（high）で確定した指摘のうち修正したもの。項目 21〜23 と同様の事後対応枠で、3.2.0 出荷の必須条件には含めない。

項目 **21〜23** は `feature/3.2.0` 全体への `/code-review` バッチレビュー（medium）で確定した指摘のうち、修正方針が明確なものを個別タスク化したもの。着手順・3.2.0 出荷の必須条件には含めない（項目 10〜15 と同様の事後対応枠）。

進捗（すべて `feature/3.2.0` 上・`master` 未マージ）: 項目 **1〜20 がすべて完了**（項目2はベゼル質感の作り直しを対象外として見送った上での完了、表の「ステータス」列参照）。項目 **21〜24 もすべて完了**。公開ドキュメント（`USAGE`/`FEATURES`/`NOTES`/`CHANGELOG` の JA+EN）は3.2.0の内容を反映済み。

| # | 機能 | 実現可能性 | 難易度 | ステータス | 優先度 |
|---|---|---|---|---|---|
| 1 | メインウィンドウの表示倍率をユーザー選択制にする | 高（拡大は `FScale100` 1 変数に集約済み） | 低〜中（ini キー＋メニュー＋`FScale100` の導出変更） | **完了**（`feature/3.2.0`、IDE ビルド検証済。ライブなモニタ倍率変更時のリサイズ含む。公開ドキュメント反映済み） | 高 |
| 2 | Vintage スキンの素材ブラッシュアップ | 高（`tools/gen_vintage.py` で機械生成） | 低（目盛り/ラベルの色調整・針の支点移動）〜中（ステレオ化は新規レイアウト＋画像生成） | **完了**（`tools/gen_vintage.py` を収録し、目盛り・ラベルの色調整、フル音量メーターのステレオ化（AudioL/AudioR）、針の回転支点をケース下端へ移動をスクリプト側の変更として実施。ベゼル質感の作り直しは3.2.0の対象外として見送り） | 中 |
| 3 | UI表示言語の手動選択（Auto/JA/EN、基盤のみ。独語・繁体字は将来版） | 高 | 中（文字列基盤の `array[TAppLang]` 化＋`.dpr` 初期化順） | **完了**（`feature/3.2.0`、IDE ビルド検証済。`array[TAppLang]` 基盤＋英語フォールバック＋Options コンボ。翻訳投入はスコープ外。公開ドキュメント反映済み） | 中 |
| 4 | GPU 使用率（PDH。CPU カードへ同居、使用率のみ） | 中〜高 | 中（ワイルドカード PDH の動的カウンタ管理が山） | **完了**（`feature/3.2.0`、IDE ビルド検証済。`uGpuCollector.pas` ＋ CPU カード Dual 化） | 中 |
| 5 | タスクトレイの独立化・LED 情報拡張（5a+5b+ディスク/ネット同時表示。ドライブ別・多段階色は別枠） | 高（設定モデルは既に分離済み・LED ソースも既存） | 中（メニュー再構成／`[Tray]` 撤去／トレイ素材 12 icon） | **完了**（`feature/3.2.0`、IDE ビルド・実機確認済み。5a/5b/5c すべて実装済み） | 中 |
| 6 | asset-editor（ブラウザ版スキン編集ツール、3.2.0 で完成版） | 高（要素技術はすべて標準ブラウザAPI） | 高（表示エンジン移植＋テキスト/GUI 両編集の同期＋バリデーション。Delphi と JS の 2 重実装が恒久コスト） | **完了**（`asset-editor/`。テキスト↔GUI 同期・コンパクト/フルプレビュー（パーツ半透明トグル含む）・バリデーション・`layout.cfg` のクリップボードコピー・`public_docs/SKIN_GUIDE.md` JA+EN を実装済み。保存はクリップボードコピーのみで、ファイルへの書き戻し機能は持たない方針で確定） | 中〜低（工数は大、必須度は中〜低） |
| 7 | ダッシュボードの最小ウィンドウサイズをDPIスケール・画面サイズに追従させる（不具合修正） | 高（原因箇所を特定済み） | 低〜中（最小サイズ算出ロジックの変更＋ワークエリアクランプの配線） | **完了**（`feature/3.2.0`、IDE ビルド検証済。200%/150% での縮小・モニター間移動・ini 復元・1000×800 DIP 緩和後のクリッピング無しを実機確認済み。電源カードの縦間隔詰めも同ブランチで実施・確認済み） | 最優先（不具合修正） |
| 8 | オプション画面を複数ページ化し、OS のライト/ダーク設定に追従させる | 高（標準 VCL 部品のみで実現） | 低〜中（`TPageControl`/`TTabSheet` への再配置＋アプリ全体への VCL スタイル適用） | **完了**（`feature/3.2.0`、IDE ビルド・実機確認済み。既存コントロールの再配置のみでロジック変更なし。ライト/ダーク切替のライブ追従を含め動作確認済み） | 中 |
| 9 | Info Bar スキンの拡張（フル表示の追加＋コンパクトの絞り込み） | 高（`layout.cfg` 追記のみで既存コードは無改修） | 低〜中（新規 LED 画像素材を追加） | **完了**（`assets/infobar/layout.cfg`。フルは旧コンパクトの内容をそのまま継承、コンパクトは Cpu バー＋ Ping ＋音量バー＋ディスク/ネット LED4個に絞ったデザインへ作り替え済み） | 中 |
| 10 | トレイアイコン読み込みロジックの重複解消 | 高 | 低 | **完了**（PR #34、`TAssetStore.LoadIconFile`/`BuildPath` へ統合） | 低 |
| 11 | asset-editor 内の重複コードの整理 | 高 | 低〜中 | **完了**（PR #35、生成物がリファクタ前とバイト完全一致することを確認済み） | 低 |
| 12 | asset-editor の Blob URL 未解放（メモリリーク）を解消 | 高 | 低 | **完了**（PR #36） | 低〜中 |
| 13 | asset-editor の検証ロジックと uSkinLoader.pas の細かい食い違いを解消 | 高 | 低〜中 | **完了**（PR #37、3件とも修正・動作確認済み） | 中 |
| 14 | tools/gen_vintage.py のハウジング毎フレーム再描画を解消 | 高 | 低 | **完了**（PR #38、生成物バイト完全一致・実行時間 約2.2秒→約0.45秒） | 低 |
| 15 | layout.cfg の重複キー処理方針を JS/Delphi 間で確定する | 高（`System.IniFiles.pas` 実ソースで確認済み） | 低（両実装とも先勝ちで一致、コード変更不要） | **完了**（`System.IniFiles.pas` 実ソースで `TMemIniFile.ReadString` が先勝ちであることを確認、`cfgModel.js` と一致。`docs/ASSET-EDITOR-VALIDATION-CHECKLIST.md` を更新） | 中 |
| 16 | 「常に手前に表示」が他の最前面窓に押し出されたまま戻らない不具合を修正 | 高（原因箇所を特定済み） | 低（フレームタイマーからの定期 `SetWindowPos` 呼び出し） | **完了**（`work/3.2.0-16-stay-on-top-repoll`、IDE ビルド・実機確認済み） | 高（不具合修正） |
| 17 | Vintage スキンの針の始点・終点が背景の目盛りと一致していない不具合を修正 | 高（原因箇所を特定済み） | 低（`tools/gen_vintage.py` の目盛り円と針のピボット・半径を一致させる） | **完了**（PR #33、実機確認済み） | 中（不具合修正） |
| 18 | ダッシュボード電源パネルの残時間表示を単位付きに改善（「1:1」→「1時間1分」） | 高（原因箇所を特定済み） | 低（`DrawPowerPanel` のフォーマット処理と文字列3件を追加） | **完了**（PR #41、実機確認済み） | 低（表示改善） |
| 19 | オプション画面のタブ上部マージンを調整（タイトルバーに近すぎる） | 高（原因箇所を特定済み） | 低（`Padding` を設定するのみ） | **完了**（PR #39、実機確認済み。左右マージン・ボタン行高さは実機での微調整を反映） | 低（表示改善） |
| 20 | タスクトレイ LED アイコンのネットグリフのデザイン調整 | 高（原因箇所を特定済み） | 低（`generate-tray-icons.ps1` の色・線幅を2箇所調整） | **完了**（PR #40、プレビュー画像でユーザー確認済み。Delphi コード変更なしのため IDE ビルド不要） | 低（表示改善） |
| 21 | オプション画面がタスクバー／Alt+Tab に表示される退行を修正（`WS_EX_TOOLWINDOW` の復元） | 高（master の実装を参照可） | 低 | **完了**（PR #42、実機確認済み） | 中（退行修正） |
| 22 | GPU 使用率取得が PDH 例外後に永久に 0% 固定になる問題を修正（再初期化・バッファ再拡張） | 高（原因箇所を特定済み） | 低〜中 | **完了**（PR #42、実機確認済み） | 中（不具合修正） |
| 23 | pre-commit フックの失敗握りつぶし・`cfgModel.js` の `;` 誤解析・asset-editor の多重読み込み競合を修正 | 高 | 低 | **完了**（PR #42。Delphi コード変更なし） | 低〜中 |
| 24 | 最終レビューの指摘: GPU 再初期化が実際には発動しない／ギャラリー画像の透過判定／トレイ・色見本アイコンが常に既定サイズで読まれる | 高（原因箇所を特定済み） | 低〜中 | **完了**（PR #44、実機確認済み） | 中（不具合修正） |

3.2.0 に収まらず次のメジャーへ送った項目（リソース別 TOP5 プロセス、ダッシュボード CRT 表示タイプ）は `docs/PLANNED-3.3.0.md`。

## 7. ダッシュボードの最小ウィンドウサイズをDPIスケール・画面サイズに追従させる（不具合修正）

Windows 表示スケールを 200% 等の高倍率に設定した環境で、ダッシュボードウィンドウの最小サイズ制限が対象モニターのワークエリア（作業領域）より大きくなり、画面に収まるサイズまでウィンドウを縮小できなくなる不具合を修正する。100% 表示の環境では発生しない。

### スコープ確定事項

- 対象は **ダッシュボード（`TDashboardForm`）のみ**。ガジェット本体（`TMainForm`）・オプション画面は対象外（`Constraints` 自体を持たず、この不具合と無関係。直近のガジェット表示倍率コミット `ebc9c09`/`bae544f` もダッシュボードを一切変更していないことを確認済み）。
- 修正は最小サイズの算出ロジックと、それを適用する箇所（起動時／DPI変更時／ディスプレイ構成変更時／ini復元時）に限定する。`LayoutContent` の列折りたたみによる縮退ロジック（[uDashboardForm.pas:412-463](../src/dashboard/uDashboardForm.pas#L412-L463)）は変更不要（既存の機構をそのまま活かす）。

### 事前検証（現行コード `src/dashboard/uDashboardForm.pas` / `src/uWindowPlacement.pas` / `src/uSettings.pas` を確認済み）

- 本アプリは `AppDPIAwarenessMode=PerMonitorV2`（[DiskLED.dproj:99,102,111,115](../DiskLED.dproj#L99)）で、OS による自動スケーリングは行われない。ダッシュボードは `Scaled=False` ＋手動 DIP→px 変換（`ScalePx(AValue, ADpi) = MulDiv(AValue, ADpi, 96)`、[uDpiScale.pas:68-75](../src/uDpiScale.pas#L68-L75)）という方式（[uThemedHudForm.pas:8-10](../src/uThemedHudForm.pas#L8-L10)）。
- 最小サイズは `ApplyDpiChrome`（[uDashboardForm.pas:243-254](../src/dashboard/uDashboardForm.pas#L243-L254)）の `Constraints.MinWidth := ScalePx(1000, Dpi); Constraints.MinHeight := ScalePx(900, Dpi);` のみで決まる。**1000×900 DIP の固定値**に DPI 比を掛けるだけで、対象モニターの実際のワークエリアサイズを一切考慮していない。200%（Dpi=192）では物理 2000×1800px まで膨らみ、モニターによっては画面に収まらない。
- `ApplyDpiChrome` は `FormCreate`（[uDashboardForm.pas:126](../src/dashboard/uDashboardForm.pas#L126)）と `WMDpiChanged`（[uDashboardForm.pas:340-358](../src/dashboard/uDashboardForm.pas#L340-L358)）の 2 箇所から呼ばれる。`ApplySavedDipBounds`（[uDashboardForm.pas:256-269](../src/dashboard/uDashboardForm.pas#L256-L269)）は ini に保存された DIP サイズを同じ `ScalePx` で物理化して `SetBounds` する。
- `ClampIntoView`（[uDashboardForm.pas:271-300](../src/dashboard/uDashboardForm.pas#L271-L300)）は、ウィンドウが全モニターから完全に外れた場合のみを救済する処理で、コメント（283-289行目）に「ワークエリアより大きい/縦長のウィンドウは意図的に扱わない」と明記されている。`WMDisplayChange`（[uDashboardForm.pas:360-366](../src/dashboard/uDashboardForm.pas#L360-L366)）もこの `ClampIntoView` を呼ぶだけ。
- ワークエリア取得用の `WorkAreaForWindow(AWnd: HWND): TRect`（[uWindowPlacement.pas:54](../src/uWindowPlacement.pas#L54)）は既に存在するが `implementation` セクション内にあり、他ユニットから呼べない。
- 副次的な不整合: `uSettings.Normalize` の ini クランプ（[uSettings.pas:271-278](../src/uSettings.pas#L271-L278)）は 800×600〜3840×2400 DIP を許容するが、`ApplyDpiChrome` が実行時に強制する最小値は 1000×900 DIP で、両者が食い違っている。DFM の設計時 `Constraints`（[uDashboardForm.dfm:8-9](../src/dashboard/uDashboardForm.dfm#L8-L9)）も 800×600 だが `Scaled=False` により起動時に `ApplyDpiChrome` で即座に上書きされ、実質死んでいる。

### 実装内容（`work/3.2.0-7-dashboard-min-size` で実装・IDE ビルド検証済み）

1. `uWindowPlacement.pas`: `WorkAreaForWindow` と `WorkAreaForRect` を `interface` セクション（[uWindowPlacement.pas:27-28](../src/uWindowPlacement.pas#L27-L28)）へ公開（ロジック変更なし）。
2. `uDashboardForm.pas` に private ヘルパーを追加:
   - `CurrentWorkArea`（[uDashboardForm.pas:247-252](../src/dashboard/uDashboardForm.pas#L247-L252)）: `HandleAllocated` なら `WorkAreaForWindow(Handle)`、そうでなければ `WorkAreaForWindow(0)`。
   - `EffectiveMinSize`（[uDashboardForm.pas:263-282](../src/dashboard/uDashboardForm.pas#L263-L282)）: ①理想値 **1000×800 DIP** を DPI 換算 → ②対象モニターのワークエリア幅/高さを超える場合はワークエリアまで縮小 → ③絶対下限 800×600 DIP（`uSettings.pas`/DFM と同じ値）を DPI 換算した値を下回らせない、の優先順位で各軸独立に算出する。
   - `ClampSizeToWorkArea`（[uDashboardForm.pas:284-294](../src/dashboard/uDashboardForm.pas#L284-L294)）: 既に決まった幅/高さをワークエリア内に収める単純なクランプ。
3. `ApplyDpiChrome`（[uDashboardForm.pas:297-308](../src/dashboard/uDashboardForm.pas#L297-L308)）: `CurrentWorkArea` を取得し、`EffectiveMinSize` の結果を `Constraints.MinWidth/MinHeight` に代入する。
4. `ApplySavedDipBounds`（[uDashboardForm.pas:311-333](../src/dashboard/uDashboardForm.pas#L311-L333)）: `SetBounds` 後、現在のワークエリアに対して `ClampSizeToWorkArea` を適用し、変化があれば `SetBounds` をもう一度呼ぶ（保存済みサイズが現在のモニターでは大きすぎるケースに対応）。
5. `WMDpiChanged`（[uDashboardForm.pas:406-427](../src/dashboard/uDashboardForm.pas#L406-L427)）: Windows が提案する `Suggested` 矩形は DIP サイズを維持するだけで新モニターの物理サイズを考慮しないため、`SetBounds` 前に `WorkAreaForRect(Suggested)` を対象に `ClampSizeToWorkArea` をかける（移動先モニターが `Handle` へまだ反映されていない可能性があるため `WorkAreaForWindow(Handle)` ではなく提案矩形基準）。
6. `WMDisplayChange`（[uDashboardForm.pas:432-450](../src/dashboard/uDashboardForm.pas#L432-L450)）: 既存の `ClampIntoView` 呼び出しの前に `ApplyDpiChrome`（ワークエリア変化に応じて `Constraints` を再度締め直す）を追加し、`HandleAllocated and (WindowState = wsNormal)` の場合のみ現在サイズをワークエリアにクランプする。
7. `uSettings.pas` / DFM の数値（800×600 DIP 下限）は変更なし。

理想サイズは **1000×800 DIP**（`EffectiveMinSize`、[uDashboardForm.pas:268-269](../src/dashboard/uDashboardForm.pas#L268-L269)）。

併せて、電源カード（`DrawPowerPanel`、[uDashboardPainter.pas:677-816](../src/dashboard/uDashboardPainter.pas#L677-L816)）の「タイトル」「ソース」「バッテリー」「バッテリーグラフ」の縦間隔を半分に詰めた。行間ギャップを `Dip(18)` から `Dip(9)` へ、タイトル→ソース間のオフセットを固定値 44dip から実測タイトル高さ＋半分ギャップへ変更。「残時間」はバッテリー行からの相対オフセットは変えていないため、詰まった分だけ自動的に上へ追従する。

### 実機で見たこと（確認済み）

- 表示スケール 150%/200% の環境で、ダッシュボードを最小サイズまで縮小しても画面内に収まる。
- 100% スケールの大きいモニターから 200% の小さいモニターへドラッグ移動すると、`WMDpiChanged` 経由で画面内に収まるサイズへ追従する。
- 大きいモニター/低スケールで保存した ini のウィンドウサイズを、小さい/高スケールのモニターで起動しても画面内に収まる。
- 1000×800 DIP 相当まで縮小しても `LayoutContent` のカード折りたたみでクリッピングが発生しない。
- 電源カードの縦間隔詰め後、残時間を含む各要素が重ならず表示される。

### 残タスク

- 項目 4 由来の積み残し（Disk / Net カードの 125%/150%/200% DPI 確認）。

## 1. メインウィンドウの表示倍率をユーザー選択制にする

**ガジェット本体（スキン）の拡大率を、画面 DPI からの自動決定に加えて、ユーザーが右クリックメニューから選べるようにする。** 既定は従来どおり自動（DPI 連動）で、**自動の結果に満足できないユーザーが明示的に固定倍率へ変更するための機能**という位置づけ。右クリックに「表示倍率」サブメニューを追加し、**`自動` / `100%` / `150%` / `200%`** を排他選択で並べる（刻みは実機テストで調整）。**この倍率はダッシュボードには適用しない**（ダッシュボードは従来どおり実 DPI）。

### スコープ確定事項

- **既定は `自動`**（DPI 連動）。手動選択は自動に不満なユーザー向けのオプトイン。
- **縮小倍率（100% 未満）は用意しない。** スキンの多くは既に小さく作り込まれており、縮小表示は開発者として非推奨。将来明確な要望が出たら再検討する。→ **拡大のみ**（`100/150/200`、自動）。
- **右クリックメニューのみで完結。** オプション画面（`uOptionsForm`）には置かない。スキン切替や配置モニターに応じてその場で手軽に変えられることを重視する。
- スキン別の推奨倍率ヒント（`layout.cfg` 側）は**不要**。

### 現状の確認結果（`src/uMainForm.pas` / `src/uDpiScale.pas` / `src/uSettings.pas` を確認）

- ガジェットの拡大は `TMainForm.FScale100`（整数パーセント）1 変数に集約されている。設定箇所は 2 つだけ:
  - `ApplyDpiScale`（[uMainForm.pas:706-714](../src/uMainForm.pas#L706-L714)）: `FScale100 := GadgetScale100(FMonitorDpi)`
  - `WMDpiChanged`（[uMainForm.pas:1386-1403](../src/uMainForm.pas#L1386-L1403)）: 同上（モニター間移動時）
- 使用箇所も 2 つ: `ApplyDpiClientSize` → `LayoutClientSize(FLayout.Width, FLayout.Height, FScale100, ...)`（[uMainForm.pas:716-725](../src/uMainForm.pas#L716-L725)）、`FormPaint` の `StretchBlt`（`DestW := MulDiv(FLayout.Width, FScale100, 100)`、[uMainForm.pas:967-980](../src/uMainForm.pas#L967-L980)）。
- `GadgetScale100(dpi)`（[uDpiScale.pas:22-34](../src/uDpiScale.pas#L22-L34)）は 0.5 刻み（100/150/200…、125%→150、下限 100）で DPI から倍率を出す。ユーザー選択制にするなら `FScale100` の導出をここではなく設定値から行う。
- `LayoutClientSize`（[uDpiScale.pas:64-71](../src/uDpiScale.pas#L64-L71)）は `AScale100 < 100` を 100 にクランプする。**拡大のみ方針なのでこのクランプは現状のままでよい**（縮小を許す場合のみ緩和が必要）。
- `WMDpiChanged` は既に「提案矩形へ `SetBounds`」を実行済み（[uMainForm.pas:1396-1400](../src/uMainForm.pas#L1396-L1400)）。**固定倍率時は `FScale100` の再代入だけスキップすれば「モニターが変わっても固定倍率のまま・提案矩形へ移動」がそのまま得られる。**
- ダッシュボードは `TDashboardForm` で完全に別系統（`FWindowDpi` / `HudMetrics`、`DashboardScale = Dpi/96.0`）。メインの `FScale100` には一切依存しないので、**倍率をダッシュボードに波及させない条件は自動的に満たされる**（追加のガードは不要）。
- `uSettings.TAppSettings` に倍率キーは無い（`[General]` は `Mode`/`StayOnTop`/`Fps`/`WindowX/Y`/`Startup`、[uSettings.pas:243-248](../src/uSettings.pas#L243-L248)）。`Normalize` の許容値バリデーション（[uSettings.pas:192-226](../src/uSettings.pas#L192-L226)、`FFps` を 10/15/20 以外なら 15 に戻す等）が倍率キーの手本になる。
- メニュー構造: 表示モード項目は `GroupIndex=1`、compact/full/tray は `GroupIndex=2`（`BuildPopup`、[uMainForm.pas:558-647](../src/uMainForm.pas#L558-L647)）。`SyncModeChecks`（[uMainForm.pas:820-833](../src/uMainForm.pas#L820-L833)）がトップレベルの `GroupIndex=1` 項目を舐めて `Checked` を触るため、**倍率項目はサブメニュー（子）に閉じ込める必要がある**（トップレベル直下に置くと干渉する）。チェック同期は `SyncViewMenu`（[uMainForm.pas:836-852](../src/uMainForm.pas#L836-L852)）と同じ流儀で書ける。

### 実装プラン（方針）

1. `uSettings` に `[General] Scale`（int パーセント、既定 `0` ＝「自動」）を追加。`0`＝自動（`GadgetScale100(dpi)`）、`100`/`150`/`200` ＝固定。`Normalize` で許容値（0/100/150/200）以外は `0` に（`FFps` のパターンを踏襲）。
2. `TMainForm` に倍率導出を 1 箇所へ集約するヘルパー（例 `function ResolveScale100: Integer`）: `FSettings.Scale = 0` なら `GadgetScale100(FMonitorDpi)`、それ以外は設定値。`ApplyDpiScale` と `WMDpiChanged` の両方をこれ経由に。
   - `WMDpiChanged` は固定倍率時 `FScale100` の再代入をスキップし、提案矩形への `SetBounds`（既存）はそのまま通す。
3. 右クリックメニュー（`BuildPopup`）に「表示倍率」サブメニュー（`TMenuItem` の子）を追加。子項目は `RadioItem := True` ＋独自 `GroupIndex`（例 `3`）。`OnClick` で `FSettings.Scale` を更新 → `ApplyDpiScale` → `PersistSettings`。文字列 ID は `menu.scale`（親）＋ `menu.scale_auto`（自動）のみ。数値項目のキャプションは `Format('%d%%', [Pct])` で生成し固定 ID（`menu.scale_100` 等）は作らない（段階を増やしても文字列追加不要）。
4. `SyncViewMenu` 相当のチェック同期を倍率サブメニューにも（現在の `FSettings.Scale` に一致する子を `Checked`）。
5. 公開ドキュメント（`USAGE.md` / `FEATURES.md` の JA+EN）に「表示倍率」の説明を追記（実装後）。

### 実装後に実機で見ること

- 自動/100/150/200 の 4 択で足りるか（例えば 125% や 175% が要るか）を実機で確認し、刻みを調整。
- 固定倍率でモニター間を移動 → 倍率が変わらず提案位置へ移動すること。
- 固定倍率時のホバーチップ位置・ドラッグ矩形（`FMonitorDpi` ベースのまま、倍率と独立）が破綻しないこと。
- トレイアイコンは DPI ベースのまま（`LoadIconMetric`）で倍率の影響を受けないこと。

見積り: 半日〜1 日（`FScale100` の導出変更＋メニュー＋ini キー。ダッシュボード非波及は構造上自動）。

## 2. Vintage スキンの素材ブラッシュアップ

3.1.2 で追加した Vintage スキン（アナログ VU メーター）の素材は Pillow による機械生成を正式版として採用済み。文字盤・ベゼル等の質感を丸ごと作り直す大掛かりな改修は見送り、視認性・リアリティに直結する3点のみ着手した。

### 生成スクリプト

ベース絵を作る Pillow スクリプトを `tools/gen_vintage.py` としてリポジトリに収録済み。単一ファイル・依存は Pillow のみで、`assets/vintage/` の全 PNG（`vintage_*.png`・`vintage_compact_bg.png`・`vintage_full_bg.png`・`vintage_lamp.png`）を実行のたびに再生成する。素材の調整はこのスクリプトの定数を変更して再実行する方式で行い、PNG を直接編集しない。開発者専用ツールで **リリース配布物には含めない**（`tools/stage-dist.ps1` のコピー対象外、他の `tools/*.ps1` と同じ扱い）。トレイアイコン生成は含まない（項目5の `[Tray]` 撤去により、トレイ素材はスキン非依存の `tools/generate-tray-icons.ps1` が担う）。

### 実施内容

- **目盛り・ラベルの色調整**: `tools/gen_vintage.py` の `TICK_COL`/`LABEL_COL` は、素の `INK_COL`（(30,26,20)）を面の地色 `CREAM_HI` へ 35%（`INK_FADE`）ブレンドした色（赤針・赤ゾーン目盛り `RED_COL` は対象外）。目盛り・ラベルを薄くすることで針の視認性を上げている。全メーター・全64フレームに適用済み。
- **フルの音量メーターをステレオ化**: `METERS` に `AudioL`/`AudioR`（表示ラベルはどちらも既存の "SND" 相当のデザインを流用しつつ "L"/"R"）を追加し、`FULL_CELLS` の `SND` を `AudioL`・`AudioR` の2枠に置き換えた。生成される `vintage_sndl.png`/`vintage_sndr.png` は他メーターと全く同じ生成過程（同じ housing/tick/needle 描画関数）で作られるため画質・スタイルは完全に統一される。スクリプトが自動計算するレイアウト座標（実行時に標準出力へ表示される）に合わせて `assets/vintage/layout.cfg` の `[AudioLFull]`（X=324）/`[AudioRFull]`（X=370）と `[GeneralFull] Width`（370→416。メーター1個分46px拡張）を更新した。コンパクトの音量メーター（`[AudioCompact]`、`vintage_snd.png` のまま）はモノラルのまま変更なし。
- **針の回転支点はケース下端**: `draw_meter_case` の `pivot_y` はケース自身の下端（`y0 + case_h`）— 実機のメーターでネジ／ランプが乗る黒帯より、さらに一段下、パネルのベゼルに隠れる位置にある。針はパネル下端（`py1`）より下を描画しないようクリップし（`ImageChops.multiply` でアルファをマスク）、支点分だけ長さを伸ばして中央値での針先位置を保っている。ネジ／ランプの位置（黒帯中央、`scy = (py1 + (y0+case_h)) / 2`）は針の支点とは独立。全10メーターに適用済み。

ベゼル・文字盤の質感を作り直す本来のブラッシュアップは 3.2.0 の対象外として見送った。`tools/gen_vintage.py` が使えるようになったため、着手する際は定数変更→再実行で試行できる。

### 事前調査で分かったこと（`assets/vintage/` を確認）

- **エンジン側の制約（新素材もこれを守る）**: 各 `vintage_<meter>.png` は **44×32px × 64 コマ**の縦ストリップで、文字盤・目盛り・ラベル・針を毎フレーム焼き込み、外周のみ `#FF00FF` 色キー（全 64 コマで外形不変）。[assets/vintage/layout.cfg:20-25](../assets/vintage/layout.cfg#L20-L25)。活動ランプは別スプライト `vintage_lamp.png`（2 コマ）、ランプ無しのメーター（CPU/MEM/SWP/SND/AudioL/AudioR）は軸位置にネジを焼き込み。
- **44×32px は極小** — 「クロムベゼル」等の細かな質感は視認限界。実際に効くのは針の質・文字盤コントラスト・バックライトの暖かみ・目盛りの可読性。ブラッシュアップの焦点はそちらに置く。
- **placeholder コメントの是正は完了**: [assets/vintage/layout.cfg:4-5](../assets/vintage/layout.cfg#L4-L5) が「Placeholder art / not checked in」のままだったのを、機械生成・配布物対象外の記述に修正済み。

## 3. UI表示言語の手動選択（基盤）

日本語 OS 上でも英語表示で使えるよう、オプション画面に表示言語設定（**Auto / 日本語 / English**）を追加する。初回起動時・Auto 選択時は現行どおり OS 言語との突き合わせで自動判定する。将来の追加言語（独語・繁体字中国語（台湾）。簡体字は対象外）に備えて文字列基盤を多言語対応構造へ作り直すが、翻訳投入そのものは将来版。

### スコープ確定事項

- **3.2.0 の対象は「基盤のみ」**: 多言語対応構造への作り直し ＋ `Auto / 日本語 / English` の手動選択 UI。**独語・繁体字中国語（台湾）の翻訳投入は将来版**（構造だけ先に用意し、後から言語データを足すだけで済む状態にする）。簡体字中国語（大陸）は対象外。
- **反映は再起動後**: 言語切替の即時反映（`BuildPopup` 再生成・全キャプション再適用・ダッシュボード/トレイ Hint 更新）はしない。Options で選択・保存 → 次回起動の言語判定で使用。Options 画面に「再起動後に反映」の旨を表示する。
- **対象は「アプリ UI 文字列」のみ。** `public_docs/` と Microsoft Store の説明文は日本語＋英語のみを継続（それ以外の言語のユーザーには英語版を案内する前提）。
- **Options 画面のコンボ配置（確定）**: `CardWindow` パネル内に置く。縦位置は `ChkStayOnTop`（"Always on top"）と同じ行、カードに対して右寄せ。選択肢の表記は各言語の自称表記（`Auto` / `日本語` / `English`）。

### 技術的な裏付け（`src/uAppStrings.pas` / `src/uSettings.pas` / `src/uOptionsForm.pas` / `DiskLED.dpr` を確認済み）

1. **文字列基盤は2言語決め打ち**: `TAppLang = (alJapanese, alEnglish)`（[uAppStrings.pas:9](../src/uAppStrings.pas#L9)）、文字列本体は `TStrEntry{Id, Ja, En}` の固定2フィールド構造で `AddStr` により **133 件**登録（`S()` 呼び出しは 116 種）（[uAppStrings.pas:22-44](../src/uAppStrings.pas#L22-L44)）。`S()` は `GLang = alJapanese` の分岐で `.Ja`/`.En` を返すだけ（[uAppStrings.pas:246-261](../src/uAppStrings.pas#L246-L261)）。
2. **`AppLanguage()`（enum ゲッター）はユニット外から一度も呼ばれていない** — ローカライズは全て `S()` 経由で、言語による分岐レイアウト・挙動差は存在しない。**純粋な文字列差し替えで、`TAppLang` の拡張・`S()` のルックアップ化は安全**（`grep` で確認済み）。
3. **構造変更の方針**: `TStrEntry` を `Id: string; Text: array[TAppLang] of string;` に置き換え、`S()` を「`Text[GLang]` を返す。空なら（かつ `GLang <> alEnglish` なら）`Text[alEnglish]` へフォールバック」に変更する。この英語フォールバックにより、独語・繁体字は後から一部だけ訳した状態でも出荷できる。`AddStr(Id, Ja, En)` は当面そのまま（`Text[alJapanese]`/`Text[alEnglish]` を埋める）、追加言語は別途オーバーレイ登録で足す。書式指定子（`%s`/`%d`）を持つのは 6 件（`menu.update` / `tray.update` / `err.image_not_found` / `err.assets_dir_missing` / `err.mode_id_duplicate` / `err.unknown_mode`）＋ `uSkinLoader.pas` の `CreateFmt` 数件のみ。
4. **`.dpr` の順序問題（重要）**: `InitAppLanguage` は [DiskLED.dpr:56](../DiskLED.dpr#L56) で、`FSettings.Load`（[uMainForm.pas:296](../src/uMainForm.pas#L296)、`Application.CreateForm` 経由）**より前**に走る。`[View] Size` は `FSettings.Load` 内で読むので「同じパターン」は使えない。**手動言語は `InitAppLanguage` より前に ini を読む必要がある。** 対策: `TAppSettings` に `class function ReadLanguagePref: string`（`ResolvePath` 相当のパス解決 ＋ `[General] Language` だけを読む軽量メソッド）を追加し、`.dpr` で `InitAppLanguage` の前に呼んで結果を渡す。`InitAppLanguage(APref: string)` に引数を足し、`APref` が `auto`/空なら現行の OS 判定、`ja`/`en` なら固定。
5. **Auto 判定の実装**: `IsJapaneseUi` は `GetUserDefaultUILanguage` を `(Lang and $3FF) = LANG_JAPANESE` で判定（[uAppStrings.pas:221-227](../src/uAppStrings.pas#L221-L227)）。3.2.0 の基盤スコープでは `Auto` は現行どおり「日本語 OS なら日本語、それ以外は英語」のままでよい。将来 独語（`LANG_GERMAN` はプライマリID判定でOK）・繁体字（`0x0404` 台湾／`0x0C04` 香港／`0x1404` マカオ等のサブ言語ID完全一致。簡体字 `0x0804` は弾く）を足すときに `DetectUiLang: TAppLang` へ一般化する。
6. **ini キー**: `uSettings` に `[General] Language`（`auto`（既定）/ `ja` / `en`。将来 `de` / `zh-Hant` を追加）を新設。`Normalize` で許容値以外は `auto` に（`FFps` パターン）。`TAppSettings` としても property を足し、Options が読み書きする。
7. **Options 画面**: `uOptionsForm` は `.dfm` 設計（`ChkStayOnTop` 等の名前付きコントロール、[uOptionsForm.dfm](../src/uOptionsForm.dfm)）。`CardWindow` パネルに `TLabel` + `TComboBox`（`csDropDownList`、項目 `Auto`/`日本語`/`English`）を **`ChkStayOnTop` と同じ行・右寄せ**で追加（`.dfm` 編集を伴う）。値は property の `auto|ja|en` と対応。「再起動後に反映」ラベルの文字列 ID（例 `opt.language` / `opt.language_restart_hint`）を追加。`ApplyCaptions`（[uOptionsForm.pas:167](../src/uOptionsForm.pas#L167)）で自 form のキャプションは再適用できるが、再起動方針なので不要。

### 実装後に実機で見ること

- 日本語 OS で `English` 固定 → 再起動 → 右クリックメニュー・オプション・ダッシュボード・トレイ Hint が全部英語。`Auto` に戻して再起動 → 日本語へ復帰。
- 英語 OS で `日本語` 固定が効くこと（フォントリンクで日本語グリフが出ること。ダッシュボード／Options は `Font.Name='Segoe UI'` 直書き ＋ Windows フォントフォールバック。[uDashboardPainter.pas:130](../src/dashboard/uDashboardPainter.pas#L130)）。
- 未訳の追加言語を選んだ場合に英語フォールバックで表示が崩れないこと（将来言語を足したとき）。

### 見積り

- 文字列基盤の多言語対応（`array[TAppLang]` 化 ＋ `S()` フォールバック ＋ `.dpr` の早期読込 ＋ ini キー ＋ Options コンボ ＋ 再起動ヒント）: 2〜3 日。翻訳作業は 3.2.0 スコープ外。
- リスクは低め（言語による分岐が存在しない純粋な文字列プラミングで、`grep` で確認済み）。

## 4. GPU セクション（使用率のみ）

GPU 使用率をダッシュボードに追加する。**PDH の `GPU Engine` カウンターで使用率のみ**を取る。VRAM・温度・クロック・エンジン種別内訳は取らない（VRAM は非公開 API 依存で非採用、他は今回スコープ外）。

### スコープ確定事項

- **表示は CPU カードへ同居**（新規セクション行は作らない）。`TDashboardCard` の既存 Dual モード（[uDashboardCard.pas:29](../src/dashboard/uDashboardCard.pas#L29)、ディスク Read/Write・ネット In/Out と同じ仕組み）で CPU カードを `Lane=dlCpu` / `Lane2=dlGpu` にし、同心ドーナツ（外=CPU、内=GPU）＋履歴グラフ 2 本線＋凡例「CPU」「GPU」で見せる。右カラムの CPU サブセクション（名前・コア・クロック）は CPU 専用のまま変更しない。**ダッシュボードのレイアウト（5 行構成）は一切変えない。**
- **マルチ GPU は「最もビジーな GPU」**（アダプタ間 max）。各アダプタの使用率 = そのアダプタのエンジン群の最大値（プロセス横断で合算 → エンジン種別間で max。タスクマネージャの各 GPU カードの数字と同じ計算）。アダプタ間はさらに max。単一 GPU 機では合算でも max でも同じ。集計単位は `PdhExpandWildCardPathW` の instance 文字列から取れる `luid` と `engtype`（[tools/probe-gpu-counters.ps1](../tools/probe-gpu-counters.ps1) で検証済み）。
- **仮想ディスプレイアダプタ（Meta Virtual Monitor 等）は 3.2.0 では除外しない**（全アダプタ間 max に含める）。LUID→物理/仮想の判定にクリーンな API が無く、仮想アダプタが持続的な 3D/compute 負荷を持つことも稀。実負荷時に問題が観測されたらフィルタを追加する。
- **ガジェット本体（スキン）へのメーター追加はしない。** ただしコレクタ・パイプライン・スナップショットは将来スキンで使えるよう整備する（下記）。ガジェットの layout.cfg パーツ枠（`[Gpu*]` セクション読取）は、3.1.2 の「セクションが無ければそのパーツは存在しない」設計により後付けが非破壊なので、実際にスキンが要求するまで見送る（`uSkinLoader`/`uLayoutTypes`/`uMeterRenderer` には触れない）。
- GPU 使用率は 0..100% の素の値なので `RangeEngine` は通さず、CPU/メモリと同じくパイプライン経由（正規化＋バリスティック）で扱う。

### 技術的な裏付け（`src/metrics/*` / `src/dashboard/*` を確認済み）

1. **難所は PDH `GPU Engine` カウンターが動的インスタンス**であること。インスタンス名は LUID・PID・エンジン種別（3D / Copy / VideoDecode 等）ごとに生成され、GPU コンテキストの開閉で増減する。現行 PDH 実装（[uDiskCollector.pas](../src/metrics/uDiskCollector.pas)）は `\PhysicalDisk(_Total)\...` の**固定インスタンス**を `PdhAddEnglishCounterW`＋`PdhGetFormattedCounterValue` で読むだけで、ワイルドカード対応（`PdhExpandWildCardPathW` / `PdhGetFormattedCounterArray`）は未宣言＝新規実装。パス `\GPU Engine(*)\Utilization Percentage` を定期的に再展開・集計する。
2. **パイプライン配線（機械的だが横断的、6〜7 ファイル）**: ドーナツは `FPipeline.State.Cpu`（バリスティック値、[uDashboardForm.pas:476](../src/dashboard/uDashboardForm.pas#L476) `ApplyDonutLevels`）を使うため、`Gpu` フィールドを `TMetricsSnapshot`（`uMetricsTypes.pas`）／`TNormalizedMetrics`／`TDisplayState`／`TMeterBallistics`／`uDisplayPipeline`／`uCollector`（`FGpu` 生成・`Collect` で `Result.GpuUsage` セット・`except` フォールバック）へ足す。新規ユニット `src/metrics/uGpuCollector.pas` を `DiskLED.dpr` に追加。
3. **履歴レーン**: `uDashboardHistory.pas` に `dlGpu` を `TDashboardLane` へ追加（`array[TDashboardLane]` は自動拡張）。`TDashboardSample.Gpu`／`Push`／`AccrueDashboardPeak` に Gpu を足す。`uMainForm.TimerTick`（[uMainForm.pas:928](../src/uMainForm.pas#L928)）の `DashSample.Gpu := FPipeline.Normalized.Gpu`。ユニット冒頭コメント「8 lanes」は現状すでに 7 で古い → 8 に是正。
4. **CPU カードの Dual 化**: `uDashboardForm.pas` の `FCards[0]` セットアップ（[uDashboardForm.pas:143-145](../src/dashboard/uDashboardForm.pas#L143-L145)）に `Dual := True` / `Lane2 := dlGpu` / `Accent2 := Pal.Gpu` / `Legend1 := S('dash.cpu')` / `Legend2 := S('dash.gpu')` / `LineStyle2`。`ApplyDonutLevels` に `FCards[0].Level2 := Clamp01(FPipeline.State.Gpu)`。`ApplyPalette` の `FCards[0].Accent2`。
5. **テーマ色**: `uDashboardTheme.pas` に `Pal.Gpu`（アクセント色）を追加。
6. **文字列**: `uAppStrings.pas` に `dash.gpu`（JA「GPU」/ EN「GPU」）。

### 実装後に実機で見ること

- 単一 GPU 機（iGPU のみ / dGPU のみ）で、タスクマネージャの GPU 使用率とドーナツ・グラフが概ね一致。
- ノート（iGPU＋dGPU）で、負荷が iGPU→dGPU に移ったとき値が追従（「最もビジーな GPU」）。
- GPU 使用の激しい/idle な状態でカウンタ再展開時に値が飛ばない・PDH ハンドルリークが無い。
- GPU カウンタが存在しない環境（古い Windows、RDP セッション等）でフォールバック（内ドーナツ 0・グラフ 0）が破綻しない。

### 見積り

3〜5 日（ワイルドカード PDH の新規実装＋アダプタ/エンジン集計＋パイプライン横断配線＋実機検証。CPU カード同居のためレイアウト改修は無し）。

## 5. タスクトレイの独立化・LED 情報拡張（完了）

3.1.1 で「表示サイズ＝コンパクト／フル／タスクトレイ」の排他 3 択としてタスクトレイ LED（ディスク Read/Write 統合 ON/OFF）を実装済みだった。3.2.0 の 5a〜5c ですべて実装済み。**ドライブ別 LED と多段階色化は別枠（将来版）のまま**。

### 実装内容

- **5a. ウィンドウ表示とトレイ LED の分離**: 右クリックの表示メニューを **「ウィンドウのみ／ウィンドウ＋トレイ LED／トレイ LED のみ」の排他 3 択**（[uMainForm.pas:671-689](../src/uMainForm.pas#L671-L689)、GroupIndex 4）に組み替えた。「ウィンドウ＋トレイ LED」でウィンドウを出したままトレイも LED 化できる。ウィンドウサイズ（コンパクト/フル）は従来どおり別軸。ini は `[View] WindowHidden` ＋ `[Tray] Led` の直交キー（旧 `[View] Size=compact|full|tray` は起動時に読み替え、保存時に削除）。`TimerTick` はウィンドウ描画とトレイ LED 更新を独立条件にし、両立を可能にした。
- **5b. `[Tray]` を廃止し、スキン非依存の「トレイ LED の色」を導入**: スキンの `layout.cfg` `[Tray]` セクションと `TDisplayModeDef.TrayOffFile`/`TrayOnFile` を撤去。`assets/tray/<color>/` に緑・青・赤の Off/On アイコンを用意する。素材は [tools/generate-tray-icons.ps1](../tools/generate-tray-icons.ps1)（PowerShell + System.Drawing）によるプロシージャル生成（リング付きグラデーション球体、On はベル型減衰で明度を強調）。`assets/tray/` は `uDisplayModes.LoadDisplayModes` から明示除外（[uDisplayModes.pas:94-98](../src/view/uDisplayModes.pas#L94-L98)）。赤の Off はほぼ黒に近い暗さにして警告色との誤読を防止。
- **5c. ディスク／ネット LED**: オプション画面「Tray LED」カードの「トレイ LED の情報」（ディスク／ネットワークの独立チェックボックス、`opt.tray_led_info`）で選ぶ。**両方同時 ON が可能**で、その場合は2つ目のトレイアイコン（`FTray2`、[uMainForm.pas:1300-1334](../src/uMainForm.pas#L1300-L1334)）を動的に生成し、既存アイコンがディスク・2つ目がネットの LED を独立して表示する。グリフ形状はディスク＝横二重バー、ネット＝上下三角で区別。ini は `[Tray] LedDisk`/`LedNet` の独立ブール2個。両方を OFF にはできない（片方を外した結果もう片方も OFF になる場合はその操作をキャンセルする、[uOptionsForm.pas](../src/uOptionsForm.pas) `ChkLedDiskClick`/`ChkLedNetClick`）。
- トレイアイコンの表示位置・並び順（メイン領域／オーバーフロー、どこに並ぶか）は Windows シェル側が管理・記憶するもので、DiskLED のスコープ外（`Shell_NotifyIcon` の識別情報に紐づけて OS が保持）。将来のドライブ別 LED も同様に、ドライブごとの独立トレイアイコンとして追加され、配置は OS 管理になる見込み。

### 5c ドライブ別 LED（別枠・将来版の設計メモ、未着手）

- `uDiskCollector.pas` は `\PhysicalDisk(_Total)` 固定（[uDiskCollector.pas:142](../src/metrics/uDiskCollector.pas#L142)）。論理ドライブ別は `\LogicalDisk(<ドライブ文字>)` の**動的列挙**（USB 抜き差しでカウンタ再構築）＝本ドキュメント項目 4（GPU）と同じ課題クラス。項目 4 の PDH ワイルドカード基盤を流用できる。
- ドライブラベル（C/D…）の表示: **OFF アイコンにのみレターを描く**（ON は点灯のみ）。レターは**実行時合成**（ベース OFF LED に GDI テキストを重ねて `HICON` 化。任意の文字・`_Total` 無印も同経路）。**要求サイズ 24px 以上のときだけレターを描く**（`LoadIconMetric(LIM_SMALL)` = 16@100% / 20@125% / 24@150% / 32@200%）。16px はレター無し＋Hint でドライブ識別。閾値は実装時に実描画で調整。

## 6. asset-editor（ブラウザ版スキン編集ツール）（完了）

ブラウザ上で動く JavaScript ベースのスキン編集エディタを、`assets/` とは別の新規トップレベルフォルダ `asset-editor/` に同梱する。layout.cfg のテキスト編集と GUI 編集（両者リアルタイム同期）、同階層の画像取り込み、DiskLED.exe と同じ表示エンジンでの組み立てシミュレーション、CPU/ディスク/ネット等の値を画面上で指定して表示の変化を確認できるプレビュー（背景以外の各パーツを50%透過にする重なり確認用トグルを含む）、記述ミスのアラート表示、PC ローカルの cfg・画像の読み込みと layout.cfg 全文のクリップボードコピーを持つ（ファイルへの保存機能は持たず、書き戻しはユーザーに委ねる）。あわせてエンドユーザー向けの assets リファレンス／自作マニュアルも同梱する。

**3.2.0 で完成版を出す（項目内で最大規模。開発に時間をかけてよい）。** リリース前に開発者自身がこのエディタで既存スキンの追加・修正を行う予定＝ドッグフーディングが品質ゲート。

### スコープ確定事項

- **3.2.0 = 完成版**: テキスト編集 ＋ GUI 編集（リアルタイム同期。片方先行はしない）／コンパクト・フルの**両モードをトグルで切替えて両方チェック**（compact/full は同じ layout.cfg 内の独立セクション集合で、扱う設定量に差が少ないため片方だけの MVP にしない）／プレビュー（メーター・LED・数値readout・推移グラフ・Ping・パーツ半透明トグル）／バリデーション（記述ミスのアラート）／ローカル cfg・画像の読み込みと layout.cfg のクリップボードコピー。
- **ファイルへの保存機能は持たない**。エディタは `layout.cfg` をディスクへ書き戻さず、**Copy**（クリップボードへコピー）のみを提供する。アセットフォルダの `layout.cfg` へ反映するのはユーザー自身の作業とする。
- **エディタ画面の UI 言語は英語のみ**（アプリ本体の多言語対応＝項目3 とは別。エディタは英語で統一）。
- **同梱ドキュメント（`public_docs/` に `SKIN_GUIDE.md` の JA+EN 新規ペア）はエディタ本体と同時に 3.2.0 で出す**。`docs/MAINTAINING-PUBLIC-DOCS.md` の文書表も更新。
- **2 重実装の扱い**: Delphi 側（`uSkinLoader.pas`）変更時に asset-editor の JS パーサ／バリデータを追従改修する運用を受容。`docs/CONTRIBUTING.md` に明記し、あわせて layout.cfg fixture ＋ 期待バリデーション結果の**人力チェックリスト**を用意する（CI は無いので機械照合はしない）。
- **バリスティック（針の追従アニメーション）は対象外**。値→コマ番号の直接反映のみ。イージングは再現しない（`uDisplayPipeline.pas` の移植不要）。
- **トレイは対象外**: 項目 5 で `[Tray]` を廃止するため、実装時点の layout.cfg に `[Tray]` は無い。`assets/tray/` の LED タイプは asset-editor では扱わない。
- **配布はローカル同梱のみ**。`asset-editor/` を `assets/`・`styles/`・`public_docs/` と並ぶ配布対象トップレベルフォルダとして新設。
- **テキスト↔GUI 同期はフォーマット保持（確定）**: cfg を「行の配列 ＋ セクション/キー→行番号インデックス」でパースする。
  - GUI → テキスト: 変更キーの行だけ書き換え（先頭空白・行末コメント保持）。キーが無ければそのセクション末尾に挿入。セクションごと無ければ **ファイル末尾に空行 1 つ空けて追加**（作者がテキストペインで移動）。コメント・順序・空行・他キーは不変。
  - テキスト → GUI: debounce して全体再パース → バリデーション。正常なら GUI 更新、不正ならエラー表示（ファイル/セクション/キー/生値）＋ **テキストが通るまで GUI 編集を無効化**（半壊テキストを上書きさせない）。
  - 細部: セクション内のキー重複＝エラー表示（自動削除しない）／GUI が知らないキーは行を保持し「不明なキー」警告／挿入行の空白スタイルは `Key=Value` 固定／`File=` 変更時は取り込み済み画像名と照合し無ければ「画像未取り込み」警告（プレビュー時までハードエラーにしない）。
  - 行モデルのパーサ/ライタで JS 約 150〜250 行。スパイクは 5 スキンの実 cfg で「GUI 1 値変更 → テキスト差分 1 行」のラウンドトリップを最初に証明する。

### 技術的な裏付け

**表示エンジンの移植性は高い**:
- スプライトコマ選択は `TMeterRenderer.StripFrame`（[uMeterRenderer.pas:54-63](../src/view/uMeterRenderer.pas#L54-L63)）の `Round(Clamp01(value) * (frames-1))` という単純な算術で、JS へそのまま移植できる
- 色キー透過（`TransparentBlt`相当）は Canvas の `getImageData`/`putImageData` でマスク色のピクセルを alpha=0 に置換すれば再現できる
- 数値ビットマップフォント描画（`uDigitRenderer.pas`）、推移グラフの line/bar 描画（`uGraphRenderer.pas:28-40`、`THistoryBuffer` を単純なローリングバッファとして模擬すればよい）も同様に単純な Canvas 描画で再現可能
- layout.cfg は 3.1.2 でコンパクト/フル/トレイが完全独立セクション（パーツ間・モード間の継承なし）の形式に再設計済み（[assets/LAYOUT.md](../assets/LAYOUT.md)）。パーサーは素直な INI 読みでよく、モード間の継承解決ロジックは実装不要
- PNG/BMP はブラウザの `<img>`/`createImageBitmap` がネイティブ対応済みで自前デコーダ不要。ICO（トレイ用途、今回対象外）のみブラウザ間の対応が不安定
- バリスティックを対象外にしたことで、`uDisplayPipeline.pas` の時間ベースイージング（指数上昇・定速下降）を移植する必要が無くなり、実装量が大きく減る

**ローカルファイル入力・書き戻し**:
- 読み込みは `<input type="file" webkitdirectory>` およびドラッグ&ドロップで行う。Chromium は `file://` から開かれたページに対して File System Access API（`showOpenFilePicker`/`showDirectoryPicker`/`showSaveFilePicker`）を明示的にブロックする（Secure Context 判定とは別の file:// 固有の制限）ため、これらのフォールバック不要な標準 API のみを使う。
- **保存機能は持たない**。`layout.cfg` の書き戻しはクリップボードコピー（**Copy** ボタン、`navigator.clipboard.writeText` が使えない環境では `execCommand('copy')` にフォールバック）のみで、ユーザーがアセットフォルダの `layout.cfg` へ自分で貼り戻す。ネイティブ保存ダイアログ・ダウンロードのフォールバックは持たない。

**配置場所（`assets/` でも `tools/` でもなく新規 `asset-editor/`）**:
- `uDisplayModes.LoadDisplayModes`（[uDisplayModes.pas:75-135](../src/view/uDisplayModes.pas#L75-L135)）は `assets/` 直下の**サブフォルダ全部**を表示モード候補として走査し、`layout.cfg` が無ければ `Continue` で黙ってスキップする。`docs/PLANNED-3.1.2.md` 項目3（assets 読み込みの堅牢化、3.1.2 で実装済み）が**まさに同じ読み込み経路の事前検証を厳格化した**ため、「layout.cfg の無いサブフォルダをどう扱うか」の判断が今後変わる余地がある。エディタを `assets/` の外に出せば、この結合を構造的に無くせる
- `tools/`（`build.ps1`/`stage-dist.ps1`/`make-installer.ps1`/`refresh-internal-design.ps1` 等）は現状**開発者専用でエンドユーザーの配布物には一切含まれない**（[tools/stage-dist.ps1:36-65](../tools/stage-dist.ps1#L36-L65) がコピーするのは `DiskLED.exe`/`assets/`/`LICENSE.txt`/`public_docs/`/`styles/` のみ、`make-portable.ps1` も `dist/DiskLED/` を ZIP 化するだけでリポジトリの `tools/` 自体は見ない）。ここへエディタ（エンドユーザー向け配布物）を置くと、「開発者専用スクリプト置き場」と「エンドユーザー向け配布物」という異なる性質が1フォルダに混在する
- **`asset-editor/` を `assets/`・`styles/`・`public_docs/` と並ぶ配布対象フォルダとして新設**し、役割を「スキン内容（`assets/`）」「開発者専用ビルドスクリプト（`tools/`、配布物に含まれない）」「エンドユーザー向け配布物（`asset-editor/`、新規）」の3つにフォルダ名で分ける
- **`stage-dist.ps1` への影響**:`stage-dist.ps1` に `Copy-Item -LiteralPath (Join-Path $Root 'asset-editor') -Destination (Join-Path $Stage 'asset-editor') -Recurse -Force` 相当の1行を追加する必要がある（[tools/stage-dist.ps1:36-37](../tools/stage-dist.ps1#L36-L37) の既存パターンを踏襲）。MSIX 側のレイアウト（`docs/internal/リリース作業手順書.md`）にも `asset-editor\` を追記する

**バリデーション（記述ミスのアラート）**:
- `docs/PLANNED-3.1.2.md` 項目3（assets 読み込みの堅牢化、3.1.2 で実装済み）の Delphi 側厳格バリデーションルール（必須項目・数値範囲・色形式・enum・Graph 座標形式）は `src/view/uSkinLoader.pas` の `Read*` ヘルパー群に実装済み。JS 側はこれと同じルールセットを移植する
- **継続的なリスク**: 表示エンジンと同様、このバリデーションも Delphi 側（`uSkinLoader.pas`）と JS 側の**2重実装**になる。`uSkinLoader.pas` に変更が入るたびに、このエディタ側のパーサー・バリデーターも追従改修しないと「エディタでは通るのに実機では弾かれる」という信頼性の欠陥が生まれる。実装難易度そのものより、この**継続メンテナンスの負債**が最大のコスト

### ドキュメント同梱について

現状 `docs/MAINTAINING-PUBLIC-DOCS.md` の文書表には、layout.cfg 書式の説明は開発者向けの `assets/LAYOUT.md` しか無い。「assets リファレンス」「自作 assets マニュアル」はエンドユーザー向けで性質が異なるため、`public_docs/` に JA+EN 新規ペア（例 `SKIN_GUIDE.md`）として追加し、`docs/MAINTAINING-PUBLIC-DOCS.md` の文書表もあわせて更新するのが妥当。ツール本体（`asset-editor/`）とマニュアル（`public_docs/`）で置き場所の役割を分ける。

### 見積り

**未検証・項目内で最大規模（2 週間超見込み）。** 3.2.0 の主要成果物として時間をかけて作る。段階の目安:
- 表示エンジン移植（メーター・LED・数値readout・色キー透過）＋コンパクト/フル両モードのプレビュー: 数日
- 推移グラフのプレビュー（`uGraphRenderer` 相当＋ローリングバッファ mock。`[GraphFull]` は full のみ）: 数日
- テキスト↔GUI 両編集のリアルタイム同期: 未検証（最大の不確実要素）
- バリデーション移植（`uSkinLoader.pas` の `Read*` ルールを写す）＋人力チェックリスト作成
- ファイル入力（`<input webkitdirectory>`／ドラッグ&ドロップ）＋クリップボードコピー: 1〜2 日
- `asset-editor/` 新設＋`stage-dist.ps1` 1 行＋MSIX レイアウト追記: 小規模
- `public_docs/SKIN_GUIDE.md` JA+EN ＋ `docs/MAINTAINING-PUBLIC-DOCS.md` 更新
- `docs/CONTRIBUTING.md` に「`uSkinLoader.pas` 変更時は asset-editor の JS を追従」を追記
- 仕上げ: 開発者が実スキン作業でドッグフーディングし、出た不足を潰す

## 8. オプション画面を複数ページ化し、OS のライト/ダーク設定に追従させる（完了）

オプション画面（`TOptionsForm`）を、今後も設定項目が増える前提で `TPageControl`/`TTabSheet` による複数ページ構成へ再配置し、あわせて OS のライト/ダーク設定にも追従させる。既存の設定・iniキー・検証ロジックは一切変更せず、既存のネイティブコントロール（`TPanel`/`TCheckBox`/`TRadioButton`/`TEdit` 等）をページ間で再配置するだけに留める。

### スコープ確定事項

- **独自描画のコントロール刷新はしない**。ダッシュボード/Ping結果画面（`TThemedHudForm` 系）のような GDI+ 自家描画への刷新はせず、標準 VCL 部品（`TPageControl`/`TTabSheet` と既存のネイティブコントロール）のみで実現する。
- **ページ構成は既存の6枚のカードパネルをそのまま4ページへ集約**: 全般（`CardWindow`）／表示（`CardFps`+`CardScale`）／トレイ LED（`CardTrayLed`）／Ping・ネットワーク（`CardPing`、`CardThresholds` を含む）。カード内のコントロール構成・`TAppSettings` とのバインディングは無変更。
- **配色は「独自パレット」ではなく Delphi 標準の VCL スタイル機能を使う**。プロジェクトに同梱済みの `Windows10`/`Windows10 Dark` スタイル（`styles/Windows10.vsf`／`styles/Windows10Dark.vsf`）を、`uDashboardTheme.SystemUsesLightTheme`（既存、`AppsUseLightTheme` レジストリ値を読む）に応じて選択する。

### 技術的な裏付け（RAD Studio 37.0 の VCL ソース `source\vcl\Vcl.Controls.pas`/`Vcl.Themes.pas`/`Vcl.ExtCtrls.pas` を確認済み）

- **VCL スタイルはフォーム単位の `StyleName` だけでは効かない**。`TControl.IsCustomStyleActive` はクラス変数 `TStyleManager.IsCustomStyleActive`（`ActiveStyle <> SystemStyle` のときのみ True）を先に見てから、フォーム自身の `StyleName` を参照する。`TStyleManager.SetStyle`/`TrySetStyle` で**アプリ全体に一度スタイルを有効化していないと**、個々のフォームの `StyleName` は常に無視される。本プロジェクトは元々これを一度も呼んでいなかった。
- `TStyleManager.SetStyle`（`Vcl.Themes.pas`、`TStyleManager.SetStyle(Style: TCustomStyleServices)`）はスタイルが実際に変わったとき、開いている全フォームへ `CM_CUSTOMSTYLECHANGED` を送る。これにより **アプリ全体のスタイルを切り替えるだけで、開いている該当フォームが自動的に再描画される**（フォームを開き直す必要が無い）。
- `TPanelStyleHook`（`Vcl.ExtCtrls.pas`）によるパネル背景の自家描画は、`TCustomPanel.ParentBackground = True` のときのみ働く。オプション画面の全カードパネルはこれに合わせて `ParentBackground := True` にした（[uOptionsForm.dfm](../src/uOptionsForm.dfm) 内 8 箇所）。

### 実装内容

1. [uOptionsForm.dfm](../src/uOptionsForm.dfm): `PageControl1: TPageControl`（[:21](../src/uOptionsForm.dfm#L21)、`Align = alClient`）配下に `TsGeneral`/`TsDisplay`/`TsTrayLed`/`TsPing`（[:29,127,266,380](../src/uOptionsForm.dfm#L29)）の4 `TTabSheet` を配置し、既存のカードパネルをその子として再配置（ロジック変更なし）。ダイアログサイズを `ClientHeight=478`／`ClientWidth=460`（[:7-8](../src/uOptionsForm.dfm#L7)）。デザイン時にキャプションが空欄でメンテナンスしづらくならないよう、各 `TTabSheet` に他ラベルと同じ流儀の英語 `Caption` を設定（`General`/`Display`/`Tray LED`/`Ping && Network`。`&` は VCL のアクセラレータマーカーのため `&&` でエスケープ、[uAppStrings.pas:94-96](../src/uAppStrings.pas#L94-L96)）。カードパネル 8 箇所の `ParentBackground` を `False`→`True` に変更。
2. [uOptionsForm.pas](../src/uOptionsForm.pas): `TOptionsForm` は引き続きプレーンな `TForm`（独自描画基底クラスへの変更はしない）。`ApplyCaptions`（[:144](../src/uOptionsForm.pas#L144)）の先頭にタブキャプションの多言語適用（`TsGeneral.Caption := S('opt.tab.general')` 等）を追加（[:147-150](../src/uOptionsForm.pas#L147)）。文字列キー4件を [uAppStrings.pas:91-96](../src/uAppStrings.pas#L91) に追加。フォーム自身に `StyleName` は設定せず、後述の `uAppStyle` によるアプリ全体スタイルをそのまま継承する。
3. 新規ユニット [uAppStyle.pas](../src/uAppStyle.pas): `ApplyAppStyle` が `SystemUsesLightTheme` に応じて `styles/Windows10.vsf`／`Windows10Dark.vsf` を読み込み、`TStyleManager.TrySetStyle`（[:136](../src/uAppStyle.pas#L136)）でアプリ全体へ適用する。`.vsf` の内部登録名はファイル名と一致する保証が無いため、`TStyleManager.StyleNames` の読み込み前後差分で実際の名前を検出する（`LoadStyleFileName`、[:73-104](../src/uAppStyle.pas#L73)）。検出結果はライト/ダーク双方をユニット変数（[:49-50](../src/uAppStyle.pas#L49)）にキャッシュし、2回目以降の呼び出し（後述のライブ切替）でも正しい名前を再利用する。[DiskLED.dpr:69](../DiskLED.dpr#L69) で最初のフォーム生成前に一度呼ぶ。
4. **自家描画ウィンドウの除外**: メイン画面（`TMainForm`）・ダッシュボード/Ping結果画面（`TThemedHudForm` 系）はアプリ全体スタイルの対象から外す必要がある（対象のままだとネイティブ子コントロールが再スキンされ、既存の自家描画パレットと衝突する）。`StyleName := 'Windows'`（VCL 組み込みの「スタイル無し」の名前）をそれぞれの生成時に設定: [uMainForm.pas:311](../src/uMainForm.pas#L311)（`FormCreate`）、[uThemedHudForm.pas:49](../src/uThemedHudForm.pas#L49)（`CreateWnd`、ダッシュボード・Ping結果画面が共有する基底クラス）。
5. **ライブなライト/ダーク切替への追従**: `TStyleManager.SetStyle` は呼び出し時点で開いているフォームへ再描画通知を送るのみで、OS 設定がアプリ起動後に切り替わったときに自動で再度呼ばれるわけではない。アプリ生存中は常に存在する `TMainForm` に `WM_SETTINGCHANGE` ハンドラを追加し（[uMainForm.pas:163,1702-1717](../src/uMainForm.pas#L1702)）、`ImmersiveColorSet` セクションの変更（ダッシュボード/Ping結果画面が自身のパレット追従に使っているのと同じ通知、[uThemedHudForm.pas:53-59](../src/uThemedHudForm.pas#L53)）を受けたら `ApplyAppStyle` を呼び直す。

### 実機で見たこと（確認済み）

- オプション画面が全般／表示／トレイ LED／Ping・ネットワークの4タブに分かれ、既存の全設定項目が過不足なく操作できる。
- OS のライト/ダーク設定に応じてオプション画面の配色（パネル背景含む）が切り替わる。
- アプリ起動中に OS 設定をライト⇔ダークへ切り替えると、オプション画面を開いたままでも、開いていなくても次回表示時に正しく追従する。
- メイン画面（ガジェット本体）・ダッシュボード・Ping結果画面は、切り替え前後とも見た目に変化がない（`StyleName := 'Windows'` による除外が機能している）。
- Delphi IDE 上でタブキャプションが空欄にならず、他ラベルと同じ感覚でメンテナンスできる。

## 9. Info Bar スキンの拡張（フル表示の追加＋コンパクトの絞り込み）（完了）

Info Bar は同梱スキンの中で唯一フル表示を持たなかった（`[GeneralFull]` が無い）。フル表示を追加し、あわせてコンパクト側は情報密度を絞ったデザインへ作り替えた。

### 確定した設計（`assets/infobar/layout.cfg` を確認済み）

- **フル（531×16、Bg=`InfoBar_Base_Full.png`）**: 旧コンパクトの内容をそのまま引き継ぐ。`Cpu`/`Mem`/`Swap` バー、`DiskReadMeter`/`DiskWriteMeter`/`NetInMeter`/`NetOutMeter` の速度バー、`Ping`、`AudioL`/`AudioR` 音量バーをすべて表示する（[assets/infobar/layout.cfg:17-86](../assets/infobar/layout.cfg#L17)）。
- **コンパクト（285×16、Bg=`InfoBar_Base_Compact.png`）**: 情報を絞り、幅を 531→285 に縮小。`Cpu` バーのみ残し `Mem`/`Swap` バーは廃止。`DiskReadMeter`/`DiskWriteMeter`/`NetInMeter`/`NetOutMeter` の速度バーも廃止し、代わりに新規の2コマ LED（`DiskReadCompact`=`InfoBar_GreenLED.png`、`DiskWriteCompact`=`InfoBar_RedLED.png`、`NetInCompact`=`InfoBar_GreenLED.png`、`NetOutCompact`=`InfoBar_RedLED.png`）で活動有無のみを示す（[assets/infobar/layout.cfg:132-153](../assets/infobar/layout.cfg#L132)）。`Ping`・`AudioL`/`AudioR` は幅の縮小に合わせて再配置した上で残す。
- `uSkinLoader.pas` の `HasFull` 判定は `[GeneralFull]` の `Width`/`Height`/`Bg` が揃えば真になる（[uSkinLoader.pas:360-367](../src/view/uSkinLoader.pas#L360-L367)）ため、この追記だけで Info Bar でもダブルクリックでのコンパクト⇄フル切替・右クリックメニューのフル表示項目が有効になる（`FHasFull`、[uMainForm.pas:737](../src/uMainForm.pas#L737)）。Delphi 側のコード変更は不要。
- `InfoBar_GreenLED.png`/`InfoBar_RedLED.png` と同時に用意した3色目 `InfoBar_YellowLED.png` はどのセクションからも参照されなかったため削除した。

公開ドキュメント（`USAGE.md`/`NOTES.md`/`FEATURES.md`/`CHANGELOG.md` の JA+EN）は Info Bar のフル表示追加・コンパクト再デザインを反映済み。

## 10. トレイアイコン読み込みロジックの重複解消（LoadTrayIcon/LoadPreviewIcon/TrayIconPath）

`/code-review` で確認。`uMainForm.pas` の `LoadTrayIcon`（[uMainForm.pas:1232-1240](../src/uMainForm.pas#L1232)、`LoadIconMetric(..., LIM_SMALL, ...)` → 失敗時 `LoadFromFile` の順で読む）と、`uOptionsForm.pas` の `LoadPreviewIcon`（[uOptionsForm.pas:136-153](../src/uOptionsForm.pas#L136)、`LIM_LARGE` を使う点以外はロジックが同一）が実質同じ処理を2箇所に持っている。あわせて `uMainForm.TrayIconPath`（[uMainForm.pas:1224](../src/uMainForm.pas#L1224)、`assets/tray/<color>/<file>` のパス組み立て）を、`uOptionsForm.LoadLedPreviewIcons` が `IncludeTrailingPathDelimiter` の手組みで再実装している（[uOptionsForm.pas:173](../src/uOptionsForm.pas#L173)）。将来アイコン読み込みの挙動を直す際に片方だけ直して食い違う恐れがある。

- 両ユニットとも既に `uses` している `src/view/uAssetStore.pas`（`TAssetStore.LocateRoot`、[uAssetStore.pas:24,117](../src/view/uAssetStore.pas#L24)）へ、`LIM_*` を引数化した共通のアイコン読み込み関数と `TrayIconPath` 相当のパス組み立て関数を移設し、両フォームから呼ぶ形に統合する。

## 11. asset-editor 内の重複コードの整理

`/code-review` で確認。いずれも動作に影響しない保守性の指摘（`REVIEW.md` の対象範囲どおりロジックのみ、バイナリアセットは対象外）。

- `clamp01` が `asset-editor/js/renderer.js:23-27` と `asset-editor/js/historyBuffer.js:17-21` に同一定義で重複
- 真偽値の truthy 判定 `['1','true','yes','on']` が `asset-editor/index.html:528` と `:959`（`boolFromRaw`）に重複し、さらに正式な実装である `SkinReader.readStrictBool`（[skinLoader.js:133](../asset-editor/js/skinLoader.js#L133)、false 側の綴りも判定する）とも別建てで、3箇所とも食い違いうる
- `drawStrip`（[renderer.js:76-89](../asset-editor/js/renderer.js#L76)）と `drawPing`（[renderer.js:97-112](../asset-editor/js/renderer.js#L97)）がフレーム番号の求め方以外ほぼ同一処理
- `CfgDoc.setValue` のセクション未存在時の分岐（[cfgModel.js:94-104](../asset-editor/js/cfgModel.js#L94)）が `addSection`（[cfgModel.js:131-138](../asset-editor/js/cfgModel.js#L131)）のロジックをインラインで再実装
- `asset-editor/spike-roundtrip.cjs` はどこからも実行されない検証スパイクで、同じ保証は `index.html` の `runFullFieldCheck`（実装済み・全セクション横断でより網羅的）がカバー済み
- `tools/generate-tray-icons.ps1` の `Draw-Orb` 内、ベゼル用のリング状グラデーションブロックが直後のオーブ本体グラデーションブロックとほぼ同一構造

いずれも重複箇所を1箇所へ集約するリファクタリングで解消できる。

## 12. asset-editor の Blob URL 未解放（メモリリーク）を解消

`/code-review` で確認。`loadImage`（[index.html:835-842](../asset-editor/index.html#L835)）が `URL.createObjectURL(file)` で生成した URL を、フォルダの再読み込み時や `loadAssetFromEntries`（[index.html:1372-](../asset-editor/index.html#L1372)）で前回の `loadedAsset` を差し替える際にも `URL.revokeObjectURL` していない。同一ページで複数回スキンフォルダを読み込み直すセッション（スキン作者が試行錯誤する典型的な使い方）ほど、画像 Blob が解放されずメモリに残り続ける。

- `loadAssetFromEntries` の冒頭で、既存 `loadedAsset.images` に紐づく Blob URL を全て `revokeObjectURL` してから新しいアセットを読み込むようにする。

## 13. asset-editor の検証ロジックが uSkinLoader.pas と細かく食い違っている箇所の解消

`/code-review` で確認。asset-editor の JS 版パーサ・バリデータ（`docs/CONTRIBUTING.md` の「asset-editor と uSkinLoader.pas の二重実装」節が運用ルールを定義済み）と実機側の間に、次の細かい非互換がある。

- `IniFile.readInteger`（[skinLoader.js:71](../asset-editor/js/skinLoader.js#L71)）は `parseInt(raw, 10)` を使っており、`"100abc"` のような末尾にゴミが付く値を `100` として受理してしまう。実機の `Ini.ReadInteger` は `StrToIntDef` で文字列全体が数値でなければ既定値に落ちる（`Width` なら 0 になり [uSkinLoader.pas:356-357](../src/view/uSkinLoader.pas#L356) の `raise` で弾かれる）ため、asset-editor では「動く」skin が実機では起動時エラーになるケースがありうる
- `EditorFields.describeSection`（[editorFields.js:115](../asset-editor/js/editorFields.js#L115)）のセクション名判定は大文字小文字を区別する `===`/`endsWith` だが、実機の `TMemIniFile` はセクション名の大文字小文字を区別しない。`[generalcompact]` のような大小文字違いは実機では正常に読み込まれるのに、GUI エディタ側では「認識できないセクション」として編集フォームが出ない
- enum 系の `<select>` 描画（[index.html:1080](../asset-editor/index.html#L1080)）は `raw` が空のときだけ `field.options[0]` にフォールバックし、`Kind=xyz` のような「値はあるが無効」なケースでは選択肢が空欄のまま表示される

いずれも JS 側の該当関数を実機の判定ロジックに合わせて直す（`readInteger` は全体一致の正規表現チェックを追加、セクション名比較は小文字化して比較、enum フォールバックは「一致する `option` が無いとき」も対象にする）。

## 14. tools/gen_vintage.py: ハウジング全体を毎フレーム再描画している非効率の解消

`/code-review` で確認。`build_meter_strip`（[gen_vintage.py:323](../tools/gen_vintage.py#L323)）は `NEEDLE_FRAMES`（64）回のループ（[gen_vintage.py:329](../tools/gen_vintage.py#L329)）ごとに `draw_meter_case`（[gen_vintage.py:173](../tools/gen_vintage.py#L173)）を呼び直しており、針以外（ケース・ベベル・文字盤・目盛り・ラベル）は全64コマで不変にもかかわらず毎回描き直している。特に `add_inset_shadow`（[gen_vintage.py:124-145](../tools/gen_vintage.py#L124)）はピクセル単位の Python ループで、64コマ×12メーター分（本来12回で済む処理を768回）実行している計算になり、このスクリプトの実行時間の大半を占めていると見られる。

- ハウジング（ケース＋ベベル＋文字盤＋シャドウ＋目盛り＋ラベル）を1メーターにつき1回だけ描画してベース画像として保持し、64フレームぶんはそのコピーへ針だけを合成する形に変更する。

## 15. layout.cfg の重複キー処理方針を JS/Delphi 間で確定する

`/code-review` で確認。`asset-editor/js/cfgModel.js` の `findDuplicateKeys`（[cfgModel.js:179](../asset-editor/js/cfgModel.js#L179)）は同一セクション内のキー重複を「先勝ち」として扱う一方、`src/view/uSkinLoader.pas` 側は重複キー自体を検出しておらず `TMemIniFile.ReadString` の生の挙動に委ねていた。この生の挙動が先勝ちか後勝ちか未確認だった。

- 確認結果: RAD Studio 37.0 の実ソース `source/rtl/common/System.IniFiles.pas` を参照。`TMemIniFile.TSection.Add`（`SetStrings` から重複行も含め全キー行に対して呼ばれる）は検索用インデックス `FItemsDict` を `if not FItemsDict.ContainsKey(PrepKey)` の条件で埋めるため、重複キーでは最初の出現のインデックスしか記録されない。`ReadString` はこの `FItemsDict` を経由して検索するため、**`TMemIniFile.ReadString` も先勝ち**であることを実ソースで確認した。`cfgModel.js` の既存方針と一致しており、両実装の解釈は元々分岐していなかった。
- `docs/ASSET-EDITOR-VALIDATION-CHECKLIST.md` の fixture 13 の期待結果・「既知の未解決事項」節を更新済み。コード変更は不要。

## 16. 「常に手前に表示」が他の最前面窓に押し出されたまま戻らない不具合を修正

ユーザー報告により判明。「常に手前に表示」は `TMainForm.ApplySettingsToUi`（[uMainForm.pas:485-492](../src/uMainForm.pas#L485)）内で `FormStyle := fsStayOnTop` を代入することで実現しているが、これは起動時（`FormCreate`、[uMainForm.pas:406](../src/uMainForm.pas#L406)）とオプション画面で OK を押した時（`miOptionsClick`、[uMainForm.pas:1517-1533](../src/uMainForm.pas#L1517)）の2箇所でしか呼ばれない。他の最前面窓の出現などで Windows 側に最前面バンドから押し出されると、オプションを OFF→ON し直すまで元に戻らなかった。

- `TMainForm.PollStayOnTop`（[uMainForm.pas:838-865](../src/uMainForm.pas#L838)）を追加し、フレームタイマー（`TimerTick`、[uMainForm.pas:1052-1053](../src/uMainForm.pas#L1052)）から毎ティック呼んで、2秒間隔で `SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE)` を再アサートする。`FormStyle` の代入（HWND 再生成を伴う重い操作）ではなく、`uHoverTip.pas:68-69` に前例のある軽量な `SetWindowPos` 呼び出しを踏襲した。WM_DPICHANGED が信頼できないため毎ティック poll している `PollMonitorDpiChange`（[uMainForm.pas:802-832](../src/uMainForm.pas#L802)）と同じ設計パターン。
- `/code-review` で、オプション画面（モーダル）やダッシュボード／Tracert窓（モードレス）のような、topmost でない owned 窓が開いている間もこの再アサートが走ると、それらの窓がメイン窓の背後に埋もれる不具合を指摘された。`FOptionsOpen` フラグ（`miOptionsClick` で `ShowModal` 前後にセット）と `FDashboardForm`/`FTraceRouteForm` の `Visible` チェックを `PollStayOnTop` の先頭ガードに追加し、これらが開いている間は再アサートをスキップするよう対応済み。

## 17. Vintage スキンの針の始点・終点が背景の目盛りと一致していない不具合を修正

ユーザー報告により判明。Vintage スキン（[assets/vintage/](../assets/vintage/)）は `tools/gen_vintage.py` による機械生成（項目2）で、背景の目盛り弧と針を別々の中心・半径で描いているため、両端（最小値・最大値）で針が目盛りの範囲からずれて見える。

- 目盛り弧は `draw_meter_case`（[gen_vintage.py:173](../tools/gen_vintage.py#L173)）内、中心 `(cx, arc_pivot_y)`（`arc_pivot_y = fy1 + face_h * 0.07`、[gen_vintage.py:219](../tools/gen_vintage.py#L219)）・半径 `r1`〜`r_outer`（`r_outer = face_h * 0.95`、[gen_vintage.py:220](../tools/gen_vintage.py#L220)）の円弧上に `NEEDLE_MIN_DEG`〜`NEEDLE_MAX_DEG`（[gen_vintage.py:78-79](../tools/gen_vintage.py#L78)）で13本描画される。
- 針は同じ関数の別ブロック（旧: [gen_vintage.py:272-300](../tools/gen_vintage.py#L272) 相当）で、目盛りとは異なる中心 `(pivot_x, pivot_y)`（`pivot_y = y0 + case_h`＝ケース下端）から、目盛り弧の半径とは無関係な `needle_len` で直線として伸ばしていた。針の中心（ケース下端、パネルより下に隠れる想定）と目盛りの中心（パネル下端のすぐ下）が別点かつ半径も独立に決めていたため、`NEEDLE_MIN_DEG`/`NEEDLE_MAX_DEG` の角度自体は目盛り両端と揃っていても、針の先端が目盛り両端の点を通らなかった。
- 修正: 針の中心・長さを目盛り弧の中心 `(cx, arc_pivot_y)`・半径 `r_outer` に一致させた（[gen_vintage.py:266-291](../tools/gen_vintage.py#L266)）。`arc_pivot_y` は `py1`（パネル下端、クリップ境界）よりわずかに下にあるため、針の支点がベゼルに隠れる従来のデザイン意図は保たれている。独立した `pivot_x`/`pivot_y` は削除。
- 全12メーター（CPU/MEM/DSK/NET/SND/SWP/R/W/IN/OUT/AudioL/AudioR）・全64フレームに影響するため、`tools/gen_vintage.py` の定数修正 → 再実行 → `assets/vintage/` 配下 PNG 差し替えで対応した（項目2と同じ手順）。

### 実装後に実機で見ること

- コンパクト／フル両方の Vintage スキンで、各メーターの針を最小値・最大値まで振らせ、目盛りの両端と針の先端が重なること。
- 中間値でも目盛りと針の角度がずれないこと（円弧の中心を変えた場合、角度→位置の対応がずれていないか）。

## 18. ダッシュボード電源パネルの残時間表示を単位付きに改善

ユーザー報告により判明。ダッシュボードの電源パネルの残時間が `DrawPowerPanel`（[uDashboardPainter.pas:680](../src/dashboard/uDashboardPainter.pas#L680)）で `Format('%d:%02d', [H, M])` として組み立てられており、例えば残り1時間1分のとき「1:1」のような時刻風の表示になって分かりにくい。

- 単位付きの表現（「1時間1分」/「1h 1min」）に変更した。時間・分のいずれかが 0 のときはその側を省略し（「45分」/「45min」、「2時間」/「2h」）、両方 0 のときは分の表現のみ表示する（「0分」/「0min」）。
- `uAppStrings.pas` に `dash.power_remain_h`/`dash.power_remain_m`/`dash.power_remain_hm` の3つのフォーマット文字列（JA+EN）を追加し（[uAppStrings.pas:227-229](../src/uAppStrings.pas#L227)）、`DrawPowerPanel` の引数に追加して呼び出し元（[uDashboardForm.pas:691-697](../src/dashboard/uDashboardForm.pas#L691)）から渡す形にした。

### 実装後に実機で見ること

- ダッシュボードの電源パネルで、バッテリー駆動中に残時間が「H時間M分」（時間・分とも0でない場合）／「M分」（1時間未満）／「H時間」（分が0）の各パターンで単位付き表示になること。JA/EN 両言語で確認する。
- AC 電源接続時・バッテリー残時間が取得できない環境（デスクトップ機など）で「—」表示のまま変化しないこと。

## 19. オプション画面のタブ上部マージンを調整

ユーザー報告により判明。オプション画面（`src/uOptionsForm.dfm`）は `PageControl1`（`Align = alClient`、`Top = 0`）がフォームのクライアント領域全体を占めており、タブ帯がタイトルバー直下に隙間なく密着していた。

- フォームに `Padding.Top = 8` を設定。`Padding` は `TWinControl.AdjustClientRect`（VCL 実ソース `Vcl.Controls.pas` で確認済み）が `Align` 対象の子コントロールへ渡すクライアント矩形に直接反映されるため、`PageControl1` の座標計算やアンカー設定に一切手を入れずにタブ帯を8px下げられる。
- `PageControl1` は `Padding.Top` 分だけ自動的に縮むため、タブ本体・下部ボタン行（`PnlButtons`、`Align = alBottom`）の高さを従来どおり保つよう `ClientHeight` を 470→478 に広げて相殺した。
- 実機確認時にユーザーが RAD Studio IDE 上でさらに微調整: `Padding.Left`/`Padding.Right` も 8 に設定して左右対称のマージンにし（[uOptionsForm.dfm:15-17](../src/uOptionsForm.dfm#L15)）、下部ボタン行 `PnlButtons` の高さを 56→48 に詰めた。`ClientHeight`（478）は変更なし。

### 実機確認結果

- オプション画面のタブ帯とタイトルバー・左右端の間に隙間ができ、各タブ内のコントロールにはみ出し・重なりは無いことを確認済み。

## 20. タスクトレイ LED アイコンのネットグリフのデザイン調整

ユーザー要望により、`tools/generate-tray-icons.ps1`（3.2.0 項目10で `TAssetStore` へ統合したアイコン読み込みが参照するスキン非依存トレイアイコンの生成元）の `Draw-Glyph`（[generate-tray-icons.ps1:118](../tools/generate-tray-icons.ps1#L118)）が描くネット（Wi-Fi 風）グリフの見た目を調整した。

- OFF 時のグリフ色（[generate-tray-icons.ps1:133](../tools/generate-tray-icons.ps1#L133)）を白 `FromArgb(130, 255, 255, 255)` からグレー `FromArgb(130, 128, 128, 128)` へ変更。不透明度（アルファ130）は変更せず RGB の明度のみ半分に落とし、OFF 球体に馴染むようにした。
- 3本の弧の線幅（[generate-tray-icons.ps1:143](../tools/generate-tray-icons.ps1#L143)）を `InnerD * 0.095` から `InnerD * 0.065` へ変更（ON/OFF・全色共通）。プレビュー画像をユーザーに確認してもらいながら 0.095 → 0.08 → 0.065 の順に段階調整した。
- Delphi コードは一切変更していないため、RAD Studio IDE でのビルド確認は不要。`assets/tray/` 配下の `net{On,Off}.ico`（green/blue/red の計6ファイル）のみ再生成して差し替えた（`disk{On,Off}.ico` は無変更であることを確認済み）。

## 21. オプション画面がタスクバー／Alt+Tab に表示される退行を修正

`/code-review` バッチレビューで確定。`master` の `TOptionsForm.CreateParams`（`Params.ExStyle` に `WS_EX_TOOLWINDOW` を付与し `WS_EX_APPWINDOW` を外す）が、3.2.0 項目8のオプション画面再構成で失われており、オプション画面がタスクバー・Alt+Tab に独立した項目として出るようになっていた（常駐アプリで、トレイ専用表示時にはオプション画面だけがタスクバーに出る状態にもなる）。

- `TOptionsForm` に `CreateParams` のオーバーライドを復元した（[uOptionsForm.pas](../src/uOptionsForm.pas) の `TOptionsForm.CreateParams`）。内容は `master` と同一で、ガジェット本体（`uMainForm.pas` の `CreateParams`）と同じ流儀。

### 実装後に実機で見ること

- トレイメニューからオプション画面を開いて、タスクバーと Alt+Tab に「DiskLED Options」が出ないこと（ダイアログ自体は従来どおり最前面に表示され、操作できること）。
- 3.2.0 項目19（Padding）を含め、ダイアログの見た目（タイトルバーの太さなど）が意図せず変わっていないこと。

## 22. GPU 使用率取得が PDH 例外後に永久に 0% 固定になる問題を修正

`/code-review` バッチレビューで確定。`TGpuCollector.Sample`（[uGpuCollector.pas](../src/metrics/uGpuCollector.pas)）は `SamplePdh` が一度でも例外を投げると `FUsePdh := False` にして以後 `Exit(0)` するだけで、`FInitTried` が既に True のため再初期化されず、ドライバのリセットなど一時的な PDH 障害でも次回起動まで GPU 表示が 0% 固定になっていた。あわせて `SamplePdh` のバッファ拡張が1回きりで、負荷急増（GPU コンテキストが増える瞬間）に `PDH_MORE_DATA` が連続するとその1サンプルが誤って 0%（アイドル）として報告されていた。

- 実行時の失敗（`SamplePdh` の例外）の後は 30 秒間隔（`CRetryIntervalMs`）で `InitPdh` を再試行する。起動時から PDH カウンタが無い環境（古い Windows・RDP など）は従来どおり再試行しない（`FRetryPending` を例外時にのみ立てる）。
- `PDH_MORE_DATA` は最大3回（`CMaxBufGrowAttempts`）まで、報告サイズの1.25倍＋64バイトでバッファを拡張して取り直す。

### 実装後に実機で見ること

- ダッシュボードの CPU/GPU カードで GPU 使用率が従来どおり表示・変化すること（GPU 負荷をかけたとき／かけていないとき）。
- GPU カウンタの無い環境（RDP セッションなど）で、従来どおり 0% 表示のままエラーや遅延が出ないこと。

## 23. pre-commit フックの失敗握りつぶし・`cfgModel.js` の `;` 誤解析・asset-editor の多重読み込み競合を修正

`/code-review` バッチレビューで確定した3件。Delphi コードは変更していない。

- **pre-commit フック**（[tools/git-hooks/pre-commit](../tools/git-hooks/pre-commit)）: `render_skin_gallery.py` が失敗すると `&&` が短絡して `git add` されず、直後の無条件 `exit 0` で無言のままコミットが通り、`public_docs/images/skins/` が古いままになっていた。失敗時に警告を stderr へ出すようにした（フックは従来どおり best-effort でコミットは止めない）。
- **`cfgModel.js` の `KEY_RE`**（[cfgModel.js:30](../asset-editor/js/cfgModel.js#L30)）: 値中の `;` 以降をインラインコメントとして切り落としていたが、Delphi の `TMemIniFile`（VCL 実ソース `System.IniFiles.pas` の `SetStrings` で確認済み）も `skinLoader.js` の `IniFile` もインラインコメントを持たず行の残りを値として扱う。`File=my;icon.png` のような値が誤って欠落扱いになるため、コメントは行頭 `;` のみとした。同梱の全 `layout.cfg` に値中の `;` は無く、既存スキンへの影響はない。
- **asset-editor の多重読み込み**（[index.html](../asset-editor/index.html) の `loadAssetFromEntries`）: フォルダを続けて読み込むと、遅い方の読み込みが後から `loadedAsset` を上書きし Blob URL も解放されなかった。読み込みごとに連番（`loadSeq`）を持ち、置き換えられた古い読み込みは結果を捨てて自分の Blob URL を解放する。

### 実装後に確認すること

- asset-editor で同梱スキンを続けて読み込み直しても、直前に選んだスキンだけが表示されること（`asset-editor/index.html` をブラウザで開いて確認）。
- `layout.cfg` を GUI で編集した際、値・行末の空白・`;` で始まるコメント行が従来どおり保たれること。

## 24. 最終レビューの指摘: GPU 再初期化・ギャラリー画像の透過判定・アイコン読み込みサイズ

リリース前の最終 `/code-review`（high）で確定した3件。

- **GPU 再初期化が実際には発動しない**（[uGpuCollector.pas](../src/metrics/uGpuCollector.pas)）: 項目22で入れた再試行は `SamplePdh` の例外時にしか動かないが、PDH のハンドル失効は例外ではなくステータスコード（`PdhCollectQueryData` の非0）で返るため、実際には再初期化が働かなかった。`PdhCollectQueryData` が3サンプル連続（`CMaxFailsBeforeRetry`）で失敗したときも `SuspendPdh` で停止し、30秒後（`CRetryIntervalMs`）に再初期化する。
- **ギャラリー画像の透過判定**（[render_skin_gallery.py](../tools/render_skin_gallery.py)）: 実アプリ（`uSkinLoader.pas` の `ReadSprite`）は、スプライトに `MaskColor` があり `Transparent` キーが無い場合は透過（`Transparent` の既定値は `MaskColor` の有無）だが、スクリプトは `Transparent=1` のときだけ透過にしていたため、Metalic のギャラリー画像に LED 周りの黒い四角が出ていた。実アプリと同じ既定値・同じ真偽値の綴り（1/true/yes/on と 0/false/no/off）で判定するようにし、`public_docs/images/skins/metalic-{compact,full}.png` を再生成した（他のスキンは変化なし）。
- **アイコン読み込みサイズ**（[uAssetStore.pas](../src/view/uAssetStore.pas) の `LoadIconFile`）: `LoadIconMetric` は名前付きモジュールリソースかシステムアイコンしか読めず `.ico` のファイルパスは受け付けないため、常に `TIcon.LoadFromFile`（VCL は既定で `SM_CXICON`＝32px に近いフレームを選ぶ）へフォールバックし、DPI 別に用意した 16〜96px のフレームが使われていなかった（3.1.1 のトレイ実装由来）。`LoadImage(LR_LOADFROMFILE)` にシステムの小／大アイコンサイズ（`SM_CXSMICON`／`SM_CXICON`）を指定して読み込むように変更し、PowerShell から 16/20/24/28/32/40/48px の各サイズで一致するフレームが返ることを確認した。

### 実機確認結果

- ビルドが通り、トレイの LED アイコン・オプション画面の色見本・ダッシュボードの GPU 表示が従来どおり動くことを確認済み。
