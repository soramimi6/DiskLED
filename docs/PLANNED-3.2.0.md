# 3.2.0 以降 検討中（未確定）

3.1.1〜3.1.2 で見送った機能アイデア。3.2.0 以降で改めて優先度を検討する。実装するか・どう組み込むかは着手時に詳細を詰める。技術的な前提はここに残すが、設計・公開文には書かない。

事前検証（現行コード `src/` を確認済み）の結果は各項目に残してある。

3.2.0 の対象は **1・3・4・5・6・7**（項目 2 は着手順から外した保留枠）。着手順は `7 → 1 → 3 → 4 → 5 → 6`。項目 7 は不具合修正のため最優先で着手する。小規模で自己完結する 1 で 3.2.0 の作業フローを慣らし、文字列基盤（3）・動的 PDH カウンタ（4）という基盤性のある項目を先に据えてから重い項目へ進む。項目 6（asset-editor）は 3.2.0 最大の成果物で、layout.cfg 形式が項目 5 の `[Tray]` 撤去後に確定するため 5 の後に置く。各項目の相対的な優先度は表の「優先度」列を参照。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 | 優先度 |
|---|---|---|---|---|---|
| 1 | メインウィンドウの表示倍率をユーザー選択制にする | 高（拡大は `FScale100` 1 変数に集約済み） | 低〜中（ini キー＋メニュー＋`FScale100` の導出変更） | 半日〜1 日 | 高 |
| 2 | Vintage スキンの素材ブラッシュアップ | 未検証 | 中〜高（質感作り直し） | 未検証 | 保留（着手順外。機能ギャップ無し・現行デザインに満足。使い込んでから判断） |
| 3 | UI表示言語の手動選択（Auto/JA/EN、基盤のみ。独語・繁体字は将来版） | 高 | 中（文字列基盤の `array[TAppLang]` 化＋`.dpr` 初期化順） | 2〜3日 | 中 |
| 4 | GPU 使用率（PDH。CPU カードへ同居、使用率のみ） | 中〜高 | 中（ワイルドカード PDH の動的カウンタ管理が山） | 3〜5日 | 中 |
| 5 | タスクトレイの独立化・LED ソース拡張（5a+5b+ネット LED。ドライブ別・多段階色は別枠） | 高（設定モデルは既に分離済み・LED ソースも既存） | 中（メニュー再構成／`[Tray]` 撤去／トレイ素材 12 icon） | 3〜5日 | 中 |
| 6 | asset-editor（ブラウザ版スキン編集ツール、3.2.0 で完成版） | 高（要素技術はすべて標準ブラウザAPI） | 高（表示エンジン移植＋テキスト/GUI 両編集の同期＋バリデーション。Delphi と JS の 2 重実装が恒久コスト） | 未検証・最大（2週間超見込み） | 中〜低（工数は大、必須度は中〜低） |
| 7 | ダッシュボードの最小ウィンドウサイズをDPIスケール・画面サイズに追従させる（不具合修正） | 高（原因箇所を特定済み） | 低〜中（最小サイズ算出ロジックの変更＋ワークエリアクランプの配線） | 半日〜1日 | 最優先（不具合修正） |

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

### 実装プラン（方針）

1. `uWindowPlacement.pas`: `WorkAreaForWindow` のシグネチャを `interface` セクション（[uWindowPlacement.pas:25-26](../src/uWindowPlacement.pas#L25-L26) 付近）へ追加し、外部から呼べるようにする（ロジック変更なし）。
2. `uDashboardForm.pas` に private ヘルパーを追加:
   - `EffectiveMinSize(ADpi, AWork, out AMinW, AMinH)`: ①理想値 1000×900 DIP を DPI 換算 → ②対象モニターのワークエリア幅/高さを超える場合はワークエリアまで縮小 → ③絶対下限 800×600 DIP（`uSettings.pas`/DFM と同じ値）を DPI 換算した値を下回らせない、の優先順位で各軸独立に算出する。
   - `ClampSizeToWorkArea(var AWidth, AHeight, AWork)`: 既に決まった幅/高さをワークエリア内に収める単純なクランプ。
3. `ApplyDpiChrome`: `WorkAreaForWindow(Handle)`（`HandleAllocated` が false なら `WorkAreaForWindow(0)` にフォールバック、`WindowDpi` 関数[uDashboardForm.pas:226-236](../src/dashboard/uDashboardForm.pas#L226-L236)と同じパターン）でワークエリアを取得し、`EffectiveMinSize` の結果を `Constraints.MinWidth/MinHeight` に代入する。
4. `ApplySavedDipBounds`: 既存の `SetBounds` の後、現在のワークエリアに対して `ClampSizeToWorkArea` を適用し、変化があれば `SetBounds` をもう一度呼ぶ（保存済みサイズが現在のモニターでは大きすぎるケースに対応）。
5. `WMDpiChanged`: Windows が提案する `Suggested` 矩形（350-352行目）は DIP サイズを維持するだけで新モニターの物理サイズを考慮しないため、`SetBounds` 前に `ClampSizeToWorkArea` をかける。
6. `WMDisplayChange`: 既存の `ClampIntoView` 呼び出しの前に `ApplyDpiChrome`（ワークエリア変化に応じて `Constraints` を再度締め直す）を追加し、`HandleAllocated and (WindowState = wsNormal)` の場合のみ現在サイズをワークエリアにクランプする。
7. `uSettings.pas` / DFM の数値は変更不要（既存の 800×600 DIP がそのまま新しい絶対下限として実行時にも一貫して使われるようになる）。

### 実装後に実機で見ること

- 表示スケール 200% の環境で、ダッシュボードを最小サイズまで縮小しても画面内に収まること。
- ダッシュボードを 100% スケールの大きいモニターから 200% の小さいモニターへドラッグ移動し、`WMDpiChanged` 経由で画面内に収まるサイズへ追従すること。
- 大きいモニター/低スケールで保存した ini のウィンドウサイズを、小さい/高スケールのモニターで起動して確認する。
- 最小サイズ（800×600 DIP相当）付近までウィンドウを縮小し、`LayoutContent` のカード折りたたみでクリッピングが発生しないこと（発生する場合は絶対下限 DIP 値の見直しを検討）。

### 見積り

半日〜1日（最小サイズ算出ロジックの変更＋ワークエリアクランプの配線。対象はダッシュボードのみで波及範囲が狭い）。

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

**保留枠（着手順に含めない）。** 3.1.2 で追加した Vintage スキン（アナログ VU メーター）の素材は Pillow による機械生成を正式版として採用済み。現行デザインに満足しており、着手はもう少し使い込んでから判断する。文字盤・ベゼル等の質感を作り直す場合はここで検討する。機能上のギャップは無い（差し替えは `assets/vintage/` の画像をファイル単位で置き換えるだけで、コード・layout.cfg は変わらない）。

### 事前調査で分かったこと（`assets/vintage/` を確認）

- **生成スクリプトがリポジトリに無い**: リポジトリにあるのは [tools/upsample_meters.ps1](../tools/upsample_meters.ps1)（既存 16 コマ→64 コマの針スイープ補間）だけ。ベース絵を作った Pillow スクリプトはローカルのみで未コミット。1 メーターだけ調整したくても全部作り直しになる再現性ギャップがある。
  - **やること（項目 2 着手時、または独立の小タスクとして先に）**: 生成スクリプトをリポジトリへ収録する。置き場所は要検討（`tools/` 配下が候補。再生成・調整用であり **リリース配布物には含めない** 前提 — `tools/stage-dist.ps1` のコピー対象外）。あわせて `docs/internal/14-assets.md` の「リポジトリ未収録のローカルスクリプト」記述を更新する。
- **エンジン側の制約（新素材もこれを守る）**: 各 `vintage_<meter>.png` は **44×32px × 64 コマ**の縦ストリップで、文字盤・目盛り・ラベル・針を毎フレーム焼き込み、外周のみ `#FF00FF` 色キー（全 64 コマで外形不変）。[assets/vintage/layout.cfg:20-25](../assets/vintage/layout.cfg#L20-L25)。活動ランプは別スプライト `vintage_lamp.png`（2 コマ）、ランプ無しのメーター（CPU/MEM/SWP/SND）は軸位置にネジを焼き込み。
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
- リスクは低め（言語による分岐が存在しない純粋な文字列プラミングで、`grep` で確認済み）。`.dpr` の初期化順序変更だけ実機起動で要確認。

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

## 5. タスクトレイの独立化・LED ソース拡張

3.1.1 で「表示サイズ＝コンパクト／フル／タスクトレイ」の排他 3 択としてタスクトレイ LED（ディスク Read/Write 統合 ON/OFF）を実装済み。3.2.0 では **5a（ウィンドウ/トレイ分離）＋ 5b（トレイデザインのスキン非依存化）＋ 5c のうちネット LED まで**を対象とする。**ドライブ別 LED（5c 残り）と多段階色化（5d）は別枠（将来版）。**

### スコープ確定事項

- **5a. ウィンドウ表示とトレイ LED の分離**: 右クリックの表示メニューを **「ウィンドウのみ／ウィンドウ＋トレイ LED／トレイ LED のみ」の排他 3 択**に組み替える（B(i)）。「ウィンドウ＋トレイ LED」でウィンドウを出したままトレイも LED 化できる。ウィンドウサイズ（コンパクト/フル）は従来どおり別軸。
  - **ini スキーマ（確定・直交キー）**:
    ```ini
    [View]
    Compact=1          ; 従来どおり。ウィンドウサイズ／「トレイのみ」からの復帰先
    WindowHidden=0     ; 「トレイのみ」= 1
    [Tray]
    Led=1             ; トレイアイコンを LED 化（0 = アプリアイコン固定）
    LedType=green     ; green | blue | red
    LedSource=disk    ; disk | net
    ```
    メニュー3択は `WindowHidden` × `Led` の2ビット。無効な組み合わせ（`WindowHidden=1` かつ `Led=0`）は `Normalize` で `Led=1` に矯正。マイグレーション: 旧 `[View] Size=tray` → `WindowHidden=1, Led=1` ／ 旧 `compact`/`full` → `WindowHidden=0, Led=0`（3.1.1 の `Compact` legacy フォールバックと同方式）。
- **5b. `[Tray]` を廃止し、固定の「トレイ LED タイプ」を内蔵**:
  - スキンの `layout.cfg` `[Tray]` セクションと `TDisplayModeDef.TrayOffFile`/`TrayOnFile` を撤去。
  - `assets/tray/<type>/` に **緑・青・赤** の Off/On アイコンを用意（緑＝Info Bar 素材流用、青＝Metalic 素材流用、赤＝緑/青から加工生成）。ユーザー向け名称は色のみ（由来は出さない）。
  - `assets/tray/` は `uDisplayModes.LoadDisplayModes` の `assets/` 直下スキャンから**明示除外**（1 行）。3.1.2 の assets 厳格化と整合。
  - 配置はファイルのまま（`.res` 埋め込みにしない）。現行 `LoadTrayIcon` の `LoadIconMetric(0, PChar(APath), LIM_SMALL, ...)` 経路をそのまま使い、ディレクトリだけ差し替える。
  - 「トレイ LED タイプ」サブメニュー（スキン選択とは独立）。
  - 赤は警告色に読まれやすいので Off 状態を「かなり暗い赤（消灯）」にして誤読を防ぐ。中立色（グレー/アンバー）は将来追加候補。
- **5c（3.2.0 分）. ネット LED**: ソースは既存（`TDisplayState.NetActivityOn`）。トレイ LED ソースを **ディスク／ネット**から選べるサブメニュー。
  - **ディスクとネットは「ソース別グリフ形状」で区別**（b 案）: ディスク＝シリンダー/横バー系、ネット＝上下矢印系。色は「タイプ」で固定なので形で差別化。素材は 色3 × ソース2 × Off/On = 12。16px では形差がギリギリなので **32×32 を主サイズ**に、16 はフォールバック。
- **5d（別枠）. 多段階色化**: Off/On の 2 値でなくレイテンシ or 負荷で色段階。5b 完了が前提（段階数 × トレイタイプの素材）。駆動元の選択も要る。3.2.0 では扱わない。

### 技術的な裏付け（`src/uSettings.pas` / `src/uMainForm.pas` / `src/view/uDisplayModes.pas` / `src/view/uSkinLoader.pas` / `src/metrics/uMetricsTypes.pas` を確認済み）

- 設定モデルは**既に分離済み**: `FCompact` と `FTraySize` は独立 bool（[uSettings.pas:20-21](../src/uSettings.pas#L20-L21)、write [316-322](../src/uSettings.pas#L316-L322)）。排他にしているのは UI 側で、`SetCompactView`（[uMainForm.pas:771-808](../src/uMainForm.pas#L771-L808)）が compact/full 選択時に `FSettings.TraySize := False` を強制しているだけ。
- ウィンドウ非表示は `EnterTraySize` の `Visible := False` 一箇所（[uMainForm.pas:1105-1117](../src/uMainForm.pas#L1105-L1117)）。ここを「トレイ LED 有効でも『トレイのみ』以外は Visible を触らない」条件に変えれば「ウィンドウ＋トレイ LED」が作れる。
- ini 永続化は現状 `[View] Size=compact|full|tray` の排他 3 値（読 [uSettings.pas:249-264](../src/uSettings.pas#L249-L264)、書 [316-322](../src/uSettings.pas#L316-L322)）。新スキーマ（上記 5a の直交キー）へ移行。`FTraySize` 相当は `FWindowHidden` に置き換わり、`[Tray]` の 3 キー（`Led`/`LedType`/`LedSource`）が加わる。`SetCompactView` の `FSettings.TraySize := False` 強制は「compact/full 選択時は `WindowHidden := False`、`Led` はそのまま」に変える。
- トレイ Off/On は `[Tray]` セクション（任意、[uSkinLoader.pas:326-331](../src/view/uSkinLoader.pas#L326-L331)）→ `TDisplayModeDef.TrayOffFile`/`OnFile` → `TrayIconPath(Def.AssetDir, ...)`（[uMainForm.pas:1003-1037](../src/uMainForm.pas#L1003-L1037)）でスキンの `AssetDir` 経由。5b でこの経路を「選択中のトレイタイプ＋ソースの `assets/tray/<type>/` ディレクトリ」に付け替え、`[Tray]` リーダーと `TrayOffFile`/`OnFile` フィールドを撤去。既存 5 スキンの `TrayOff.ico`/`TrayOn.ico`（計 10 ファイル）を削除、`assets/LAYOUT.md` の `[Tray]` 節を削除。
- **LED ソースは既に揃っている**: `TDisplayState` に `DiskRWOn` / `DiskReadOn` / `DiskWriteOn` / `NetActivityOn`（[uMetricsTypes.pas:113-118](../src/metrics/uMetricsTypes.pas#L113-L118)）。ネット LED は `RefreshTrayIconForState`（[uMainForm.pas:1092-1103](../src/uMainForm.pas#L1092-L1103)）と `TimerTick`（[uMainForm.pas:947-948](../src/uMainForm.pas#L947-L948)）の `FPipeline.State.DiskRWOn` 参照を「選択中ソース」に差し替えるだけ。新規コレクタ不要。
- `LoadTrayIcon` は `LoadIconMetric`（正しい DPI 縮小）。`[Tray]` 欠落/失敗時のフォールバックは `ResetTrayToAppIcon`（アプリアイコン固定・LED なし）。

### 5c ドライブ別 LED（別枠・将来版の設計メモ）

- `uDiskCollector.pas` は `\PhysicalDisk(_Total)` 固定（[uDiskCollector.pas:142](../src/metrics/uDiskCollector.pas#L142)）。論理ドライブ別は `\LogicalDisk(<ドライブ文字>)` の**動的列挙**（USB 抜き差しでカウンタ再構築）＝本ドキュメント項目 4（GPU）と同じ課題クラス。項目 4 の PDH ワイルドカード基盤を流用できる。
- ドライブラベル（C/D…）の表示: **OFF アイコンにのみレターを描く**（ON は点灯のみ）。レターは**実行時合成**（ベース OFF LED に GDI テキストを重ねて `HICON` 化。任意の文字・`_Total` 無印も同経路）。**要求サイズ 24px 以上のときだけレターを描く**（`LoadIconMetric(LIM_SMALL)` = 16@100% / 20@125% / 24@150% / 32@200%）。16px はレター無し＋Hint でドライブ識別。閾値は実装時に実描画で調整。

### 見積り（3.2.0 分 = 5a + 5b + 5c ネット LED）

- 5a: ini 3 値の意味再定義＋マイグレーション＋メニュー再構成＋`Visible` 条件化で 1〜2 日
- 5b: `[Tray]` 撤去＋`assets/tray/{green,blue,red}/` 素材作成（ディスク/ネットのグリフ差 込みで 12 icon）＋ロード経路付け替え＋タイプ/ソースのサブメニュー＋ini キーで 2〜3 日
- 合計 3〜5 日＋実機検証（Win10/11 × 100/125/150/200%、隠れアイコン、explorer 再起動での載せ直し）

## 6. asset-editor（ブラウザ版スキン編集ツール）

ブラウザ上で動く JavaScript ベースのスキン編集エディタを、`assets/` とは別の新規トップレベルフォルダ `asset-editor/` に同梱する。layout.cfg のテキスト編集と GUI 編集（両者リアルタイム同期）、同階層の画像取り込み、DiskLED.exe と同じ表示エンジンでの組み立てシミュレーション、CPU/ディスク/ネット等の値を画面上で指定して表示の変化を確認できるプレビュー、記述ミスのアラート表示、PC ローカルの cfg・画像の読み書きを持つ。あわせてエンドユーザー向けの assets リファレンス／自作マニュアルも同梱する。

**3.2.0 で完成版を出す（項目内で最大規模。開発に時間をかけてよい）。** リリース前に開発者自身がこのエディタで既存スキンの追加・修正を行う予定＝ドッグフーディングが品質ゲート。

### スコープ確定事項

- **3.2.0 = 完成版**: テキスト編集 ＋ GUI 編集（リアルタイム同期。片方先行はしない）／コンパクト・フルの**両モードをトグルで切替えて両方チェック**（compact/full は同じ layout.cfg 内の独立セクション集合で、扱う設定量に差が少ないため片方だけの MVP にしない）／プレビュー（メーター・LED・数値readout・推移グラフ・Ping）／バリデーション（記述ミスのアラート）／ローカル cfg・画像の読み書き。
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

**ローカルファイル入出力**:
- Chromium 系ブラウザの File System Access API（`showOpenFilePicker`/`showDirectoryPicker`）でフォルダの直接読み書きが可能
- ただし Chromium は `file://` から開かれたページに対してこの API を明示的にブロックする（Secure Context 判定とは別の file:// 固有の制限）。**この制約は影響範囲が限定的で回避コストも低い**: 読み込みは `<input type="file" webkitdirectory>` やドラッグ&ドロップで代替でき、これらは `file://` でも制限なく動作する。保存側も `<a download>` の Blob ダウンロードにフォールバックすれば機能は完全に維持できる（配置場所を手動で `assets/<skin>/` に戻す一手間が増えるだけ）。実装は「File System Access API が使えるときは使い、使えなければ input/drag&drop＋ダウンロードにフォールバック」という定型パターンで数十行程度

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
- ファイル入出力（File System Access API＋`<input webkitdirectory>`／ドラッグ&ドロップ／`<a download>` フォールバック）: 1〜2 日
- `asset-editor/` 新設＋`stage-dist.ps1` 1 行＋MSIX レイアウト追記: 小規模
- `public_docs/SKIN_GUIDE.md` JA+EN ＋ `docs/MAINTAINING-PUBLIC-DOCS.md` 更新
- `docs/CONTRIBUTING.md` に「`uSkinLoader.pas` 変更時は asset-editor の JS を追従」を追記
- 仕上げ: 開発者が実スキン作業でドッグフーディングし、出た不足を潰す
