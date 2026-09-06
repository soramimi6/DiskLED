# 3.2.0 以降 検討中（未確定）

`docs/PLANNED-3.1.1.md` の「将来機能アイデア」から移動。3.1.1 では見送り、3.2.0 以降で改めて優先度を検討する。実装するか・どう組み込むかは着手時に詳細を詰める。技術的な前提はここに残すが、設計・公開文には書かない。

事前検証（2026-09-04、現行コード `src/metrics/*` / `src/dashboard/*` を確認）の結果は各項目に残してある。詳細は `docs/PLANNED-3.1.1.md` の版管理履歴（3.1.1 スコープ確定時点のスナップショット）も参照可能。

一覧は優先度（高い順）、同順位内は工数目安（小さい順）で並べている。

| # | 機能 | 実現可能性 | 難易度 | 工数目安 | 優先度 |
|---|---|---|---|---|---|
| 1 | UI表示言語の手動選択＋追加言語（独語・繁体字中国語） | 高 | 中（文字列基盤の作り直しが要る） | 基盤: 2〜3日／言語ごとに翻訳作業別途 | 中 |
| 2 | GPU セクション（使用率のみ） | 中〜高 | 中（動的カウンタの管理が山） | 3〜5日 | 中 |
| 2 | GPU VRAM 内訳 | 低〜中（非公式 API） | 高 | 使用率実装後に別枠 | 低 |
| 3 | タスクトレイの独立化・LED拡張・多段階色 | 高（設定モデルは既に分離済み） | 中（メニュー／アセット体系の変更） | 3〜5日 | 中 |
| 4 | リソース別 TOP5 プロセス | 中（ネットは精度に難） | 高（新規一覧 UI パラダイム） | 1〜2週間 | 中 |
| 5 | ダッシュボード CRT/キャラクターベース表示タイプ | 高 | 中〜高（新規描画一式） | 1〜2週間 | 中〜低 |
| 6 | assets エディタ（ブラウザ版スキン編集ツール） | 高（要素技術はすべて標準ブラウザAPI） | 高（表示エンジンの丸ごと移植＋UI＋バリデーション） | 未検証（項目内で最大規模、段階的見積りが要る） | 中〜低 |
| 7 | メモリ詳細・内訳（Standby/Modified） | 中（非公開 API 依存） | 中（実装は易、互換性リスクが本体） | 1〜2日＋実機検証 | 低〜中 |
| 8 | アクセスされているファイル | 低（管理者権限必須で方針と矛盾） | 最高 | 別製品規模 | 最低 |

## 1. UI表示言語の手動選択＋追加言語

日本語 OS 上でも英語表示で使えるよう、オプション画面に表示言語設定（**Auto / 日本語 / English**）を追加する。初回起動時・Auto 選択時は現行どおり OS 言語との突き合わせで自動判定する。あわせて日英以外の追加言語も検討する。**優先度: ドイツ語・繁体字中国語（台湾）を上げる。簡体字中国語（大陸）は対象外**（脱 Windows の動向を踏まえた方針判断）。

**対象は「アプリ UI 文字列」のみ。`public_docs/` と Microsoft Store の説明文は日本語＋英語のみを継続する方針で、この項目のスコープには含まない**（それ以外の言語のユーザーには英語版を案内する前提）。ユーザー数の増加が見えてから、追加言語での文章掲示を改めて検討する。

### 技術的な裏付け（2026-09-06 時点、`src/uAppStrings.pas` / `src/uSettings.pas` / `src/uOptionsForm.pas` / `public_docs/` を確認）

1. **文字列基盤は2言語決め打ち**: `TAppLang = (alJapanese, alEnglish)`（[uAppStrings.pas:9](../src/uAppStrings.pas#L9)）、文字列本体は `TStrEntry{Id, Ja, En}` の固定2フィールド構造で `AddStr` により約 100 件登録されている（[uAppStrings.pas:22-44](../src/uAppStrings.pas#L22-L44)）。`S()` は `GLang = alJapanese` の分岐で `.Ja`/`.En` を返すだけ（[uAppStrings.pas:225-240](../src/uAppStrings.pas#L225-L240)）。**Auto/JA/EN の 3 択どまりなら現行構造のままでも対応できるが、3 言語目（独語・繁体字中国語）を足すには `TStrEntry` を言語コード可変のマップ（または言語コード順の配列）に置き換え、`S()` のロジックも列挙型の二分岐からルックアップへ変更する必要がある**。約 100 件の文字列を洗い替える構造変更が翻訳作業とは別に先行タスクになる
2. **手動上書きは最初から想定だけされていた**: ユニット冒頭のコメントに「Manual override is out of scope for now (ini `Language=` later)」とあり（[uAppStrings.pas:3-4](../src/uAppStrings.pas#L3-L4)）、3.2.0 のこの項目はその「later」に当たる
3. **Auto 判定の実装**: `IsJapaneseUi` は `GetUserDefaultUILanguage` の戻り値を `(Lang and $3FF) = LANG_JAPANESE` で判定している（[uAppStrings.pas:200-206](../src/uAppStrings.pas#L200-L206)）。この `and $3FF` はプライマリ言語 ID のみを取り出すマスクで、ドイツ語（`LANG_GERMAN`）はこの方式でそのまま判定できるが、**中国語は要注意**: Win32 の LANGID は繁体字（台湾）が `MAKELANGID(LANG_CHINESE, SUBLANG_CHINESE_TRADITIONAL)` = `0x0404`、簡体字（中国本土）が `MAKELANGID(LANG_CHINESE, SUBLANG_CHINESE_SIMPLIFIED)` = `0x0804` で、どちらも `LANG_CHINESE`（プライマリID `0x04`）は共通。**プライマリ言語IDだけを見る現行方式では簡体字と繁体字を区別できない**ため、繁体字（台湾）のみ Auto 判定対象にするにはサブ言語 ID を含めた完全一致判定（`0x0404` および香港 `0x0C04`・マカオ `0x1404` 等の繁体字圏サブIDを含めるかは要検討）に変更する必要がある。簡体字（`0x0804` 等）は方針どおり対象外として弾く
4. **設定の永続化**: `uSettings.pas` に `Language=auto|ja|en|de|zh-Hant` 相当の ini キーを新設する必要がある（現状 Language キーは存在しない）。3.1.1 の `[View] Size` 追加時と同じパターン（新キー追加＋起動時読込）を踏襲できる
5. **Options 画面**: `uOptionsForm.pas` に選択 UI（コンボボックス等）を追加する必要がある。既存の `opt.*` 文字列群と同じ構造で足せる
6. **`public_docs/` は対象外（方針で確定）**: 現状は JA（ルート直下）＋ `EN/` の2言語構成で、`README/USAGE/FEATURES/NOTES/INSTALL/CHANGELOG/CREDITS` の7ファイルを両言語で維持している（[public_docs/](../public_docs/) 配下を確認）。Microsoft Store の説明文も含め、この2言語構成を継続する。**`DE/`・`TW/` の追加はこの項目のスコープに含まない**（ユーザー数の増加を見てから改めて判断）。UI文字列（短い技術用語、約 100 件、機械翻訳との相性が良い）だけが今回の対象で、public_docs の説明文（長文、より高い翻訳精度が要求される）とは切り分けて考えるという整理

### 見積り

- 文字列基盤の多言語対応（構造変更）＋ Auto/JA/EN 選択 UI: 2〜3日
- ドイツ語・繁体字中国語の UI 文字列（約 100 件）翻訳: 言語ごとに別途（機械翻訳＋要点レビューが現実的）
- `public_docs/`・Store 説明文の追加言語対応: **対象外**（方針で確定。将来ユーザー数増加時に別途検討）

## 2. GPU セクション

GPU 使用率・VRAM 使用量をセクションとして追加する。

- PDH の `GPU Engine` カウンター（Windows 10 以降）で使用率が一般権限で取得可。ベンダー非依存
- VRAM 使用量は D3DKMT 経由で取得可能だが、ドキュメントが薄い
- NVIDIA NVAPI / AMD ADL は詳細（温度・クロック）が取れるが実装コストが高くベンダー依存のため、まず PDH のみで実装する方針が堅実
- 左カラムのドーナツ＋履歴グラフのセクションとして自然に追加できる

**検証結果（2026-09-04）:**

- データ構造面の相性は良い: `TDashboardLane` は `array[TDashboardLane]` で自動拡張される列挙型（`src/metrics/uDashboardHistory.pas`）、`FCards` は `array[0..4]` の固定配列（`uDashboardForm.pas`）なので、`dlGpu` を足して 6 枚目のカードを増やすのは CPU〜ネットまでの既存 5 セクションと同じ手順で機械的にできる。GPU 使用率は 0..100% の単純な値なので `RangeEngine` を通さず CPU/メモリと同じ扱いでよい
- 難所は PDH の `GPU Engine` カウンターがディスクと違い**動的インスタンス**であること。インスタンス名は LUID・PID・エンジン種別（3D / Copy / VideoDecode 等）ごとに生成され、GPU コンテキストの開閉に応じて増減するため、`PhysicalDisk(_Total)` のような固定パスの 1 カウンタ追加では済まず、ワイルドカードパスでの列挙・集計と定期的なカウンタリストの再構築が要る
- VRAM は D3DKMT（`D3DKMTQueryStatistics` など）経由になるが非公開 API でドキュメントが薄く、使用率実装より別枠でリスクが高い。まず使用率のみで着手し VRAM は後回しにする案は妥当
- 見積り: 使用率のみで 3〜5 日（動的カウンタ管理・複数 GPU/エンジン種別の集計・実機検証込み）。VRAM を足すとさらに増える

## 3. タスクトレイの独立化・LED拡張・多段階色

3.1.1 で「表示サイズ＝コンパクト／フル／タスクトレイ」の排他 3 択としてタスクトレイ LED（ディスク Read/Write 統合 ON/OFF）を実装済み。3.2.0 では以下を検討する。

- **ウィンドウ表示とトレイ LED の分離**: 現状は「ウィンドウを隠す＝トレイ LED 化」の 1 本道。**メインウィンドウのみ／メインウィンドウ＋トレイ／トレイのみ**の 3 択に組み替え、ウィンドウを出したままトレイもLED化できるようにする
- **トレイのデザインをスキンから独立化**: 現状トレイの Off/On アイコンはガジェットのスキン（Original / Crystal / Metalic / Info Bar）に 1 対 1 で紐づく。スキンとは別軸の「トレイアイコンタイプ」をサブメニューで選べるようにする
- **LED ソースの拡張**: ディスク（全体・ドライブ別）に加えてネット、将来的にはユーザーが表示するソースを選べるようにする
- **多段階色化**: ON/OFF の 2 値ではなく、ディスクレイテンシや CPU/メモリ/SWAP の負荷を色（緑→黄→赤等）で示す

**技術的な裏付け（2026-09-05 時点、`src/uSettings.pas` / `src/uMainForm.pas` / `src/view/uDisplayModes.pas` / `src/view/uSkinLoader.pas` / `src/metrics/uDiskCollector.pas` を確認）:**

- 設定モデルは**既に分離済み**: `FCompact` と `FTraySize` は `uSettings.pas` 上で独立した bool フィールド（[uSettings.pas:20-21](../src/uSettings.pas#L20-L21)）。排他 3 択にしているのは UI 側のロジックで、`SetCompactView`（[uMainForm.pas:748-775](../src/uMainForm.pas#L748-L775)）が compact/full 選択時に `FSettings.TraySize := False` を強制しているだけ。設定モデル自体の作り直しは不要
- ウィンドウ非表示は `EnterTraySize` の `Visible := False` 一箇所（[uMainForm.pas:1064-1076](../src/uMainForm.pas#L1064-L1076)）に集約されている。ここを「トレイ LED 有効時でも Visible を触らない」条件に変えるだけで「ウィンドウ＋トレイ LED」の組み合わせが作れる
- ini 永続化は現状 `[View] Size=compact|full|tray` の排他 3 値形式（読込: [uSettings.pas:249-262](../src/uSettings.pas#L249-L262)、書込: [uSettings.pas:316-322](../src/uSettings.pas#L316-L322)）。2 軸（ウィンドウ表示／トレイ LED 有効）に分けるには読み書きの拡張とマイグレーションが要る。旧 `tray` → 新「ウィンドウ非表示・トレイ LED 有効」、旧 `compact`/`full` → 新「ウィンドウ表示・トレイ LED 無効」への読み替えは、3.1.1 で `Compact` キーを legacy フォールバックとして残した手法（[uSettings.pas:249-252](../src/uSettings.pas#L249-L252)のコメント）と同じ方式を踏襲できる
- トレイの Off/On アイコンはスキンの `TDisplayModeDef.TrayOffFile` / `TrayOnFile`（[uDisplayModes.pas:28-29](../src/view/uDisplayModes.pas#L28-L29)）経由で取得し、元は各スキンの `layout.cfg` の `[Tray]` セクション（[uSkinLoader.pas:317-318](../src/view/uSkinLoader.pas#L317-L318)）。ロード自体は `TrayIconPath(Def.AssetDir, Def.TrayOffFile)`（[uMainForm.pas:995-996](../src/uMainForm.pas#L995-L996)）でスキンの `AssetDir` を経由するため、トレイデザインをスキンから独立させるには、トレイ専用アセットを `assets/<skin>/` ではなく `assets/tray/<type>/` のような独立ディレクトリに切り出し、ロード元をスキンの `AssetDir` ではなく選択中のトレイタイプのディレクトリに差し替える改修が要る
- LED 点灯判定は現状 `FPipeline.State.DiskRWOn` 固定（`RefreshTrayIconForState` 内、[uMainForm.pas:1051-1062](../src/uMainForm.pas#L1051-L1062)）。ネット LED 化やドライブ別 LED 化、ユーザー選択式にするには、この参照先を選択中のソースに応じて差し替える抽象化が必要
- ドライブ別 LED の前提: 現行 `uDiskCollector.pas` は `PhysicalDisk(_Total)` 固定パスのみを PDH で読んでいる（[uDiskCollector.pas:142](../src/metrics/uDiskCollector.pas#L142)）。論理ドライブ別には `LogicalDisk(<ドライブ文字>)` カウンタの動的列挙が必要で、USB 抜き差し等によるカウンタ再構築という、本ドキュメント項目 2（GPU 動的カウンタ）と同種の課題を抱える
- 多段階色化は、トレイデザインをスキンから独立させれば素材が「トレイタイプ 1 種 × 段階数」で済み、スキン 4 種との掛け算を避けられる（独立化しない場合はスキン数分の重複が発生する）。ただし段階数分の ico ファイルをトレイタイプごとに用意する素材コスト自体は残る
- 見積り: 設定・UI 側の分離とマイグレーションで 1〜2 日、トレイデザイン独立化（アセット切り出し・ロード先変更・サブメニュー追加）で 1〜2 日、ネット LED 追加は小規模、ドライブ別 LED は動的カウンタ管理を含め別枠で 2〜3 日、多段階色は段階数分の素材制作が別途必要

## 4. リソース別 TOP5 プロセス

各リソース（CPU / メモリ / ディスク IO / ネット）ごとに、そのとき最も使っているプロセス上位 5 を表示する。

- CPU / メモリ: `EnumProcesses` + `GetProcessMemoryInfo` / `QueryProcessCycleTime`。一般権限で取得可
- ディスク IO: `GetProcessIoCounters`。プロセス別の Read/Write バイト累積で取得可
- ネット: プロセス別の帯域は IPヘルパーAPI では難しい。簡易的な差分計測にとどまる可能性あり
- ダッシュボードの各セクションをクリックして展開する形が自然（常時 HUD に出すと行数が増えすぎる）

**検証結果（2026-09-04）:**

- 実現可能性・難易度: 中〜高。CPU/メモリ/ディスク IO はプロセス別 API（`EnumProcesses` + `GetProcessMemoryInfo` / `QueryProcessCycleTime` / `GetProcessIoCounters`）で一般権限のまま取得できるため技術的な壁はない。ネットは案どおり困難（プロセス別帯域の一般権限 API が無く、簡易差分推定に留まる）ため、最初はネットを除いた 3 リソースに絞るのが現実的
- 工数の主因は UI: 現行の `TDashboardCard`（`src/dashboard/uDashboardCard.pas`）は固定サイズの GDI カスタム描画で、展開／折りたたみや行リストの仕組みが存在しない。TOP5 一覧を出すには、新規の一覧描画（プロセス名・アイコン・値）とカード高さの動的変更、ダッシュボードのレイアウト計算（`uDashboardForm` の `Heights[]`／`SetBounds` 群）への手当てが必要
- 全プロセスの毎ティック列挙はコストが高いため、既存の履歴 push（1 Hz、`docs/DESIGN.md` 8.6）と同程度の低頻度サンプリングにする設計が妥当
- 見積り: 収集ロジック 2〜3 日、UI（展開リスト・レイアウト対応）4〜6 日、調整・検証を含め 1〜2 週間程度

## 5. ダッシュボード CRT/キャラクターベース表示タイプ

ダッシュボードに、MS-DOS 時代のキャラクターベース CRT 表示のような見た目の表示タイプを追加する。**現行ダッシュボードの見た目を再現するのではなく**、表示する情報（CPU／メモリ／SWAP／ディスク／ネットのドーナツ・推移グラフ、ディスクレイテンシ、電源、Ping 履歴など。`README.md` の「主な機能」参照）は同じまま、表現を CRT キャラクター表示のスタイルで新規に組み立てる。

- 等幅ビットマップフォントでのセル描画、疑似スキャンライン、燐光グロー、`█▓▒░` 等のブロック文字によるバー／メーター表現、点滅カーソルブロックといった要素で構成する
- 既存のガジェットスキン機構（`layout.cfg` ベースの Original / Crystal / Metalic / Info Bar）とは別系統。ダッシュボードは `TDashboardCard`（`TCustomControl` を継承、[uDashboardCard.pas:16](../src/dashboard/uDashboardCard.pas#L16)）が `Paint` オーバーライド（[uDashboardCard.pas:109](../src/dashboard/uDashboardCard.pas#L109)）で GDI カスタム描画しており、新しい表示タイプもここに描画ロジックを追加する形になる
- ダッシュボードは `Scaled=False` で実 DPI 描画する設計（`docs/DESIGN.md` 15 節）なので、フォントサイズ・文字グリッドの DPI 比率計算は既存の仕組み（`Dpi/96`）をそのまま流用できる
- 新規に「ダッシュボード表示タイプ」という概念をどこに持たせるか（ini 設定キー、切替 UI）は要設計。既存の `[General] Mode=`（ガジェットの表示モード、[uSettings.pas:243](../src/uSettings.pas#L243)）とは別軸にする
- 見積り: 未検証。描画エンジン（フォント・スキャンライン・グロー・ブロック文字メーター）一式の新規実装が主で、既存セクション相当の情報量をキャラクター表現に落とし込む調整を含めると 1〜2 週間程度と見込むが、実機での見た目調整（フォント選定・色調・グロー強度）次第で変動する

## 6. assets エディタ（ブラウザ版スキン編集ツール）

ブラウザ上で動く JavaScript ベースの簡易エディタを、`assets/` とは別の新規トップレベルフォルダ `skin-editor/` に同梱する（配置場所の判断は下記参照）。layout.cfg のテキスト編集、同階層の画像取り込み、DiskLED.exe と同じ表示エンジンでの組み立てシミュレーション、CPU/ディスク/ネット等の値を画面上で指定して表示の変化を確認できるプレビュー、記述ミスのアラート表示、PC ローカルの cfg・画像の読み書きを持つ。あわせてエンドユーザー向けの assets リファレンスと自作 assets マニュアルも同梱する。

**スコープ確定事項**:
- **バリスティック（針の追従アニメーション）は対象外**。値→コマ番号の直接反映のみで、上昇・下降のイージングは再現しない
- **タスクトレイ用アイコン（`[Tray]` の Off/On ico）のプレビューは対象外**
- **配布はローカル同梱のみ**。
- **配置場所は専用の新規トップレベルフォルダ `skin-editor/`**

### 技術的な裏付け

**表示エンジンの移植性は高い**:
- スプライトコマ選択は `TMeterRenderer.StripFrame`（[uMeterRenderer.pas:54-63](../src/view/uMeterRenderer.pas#L54-L63)）の `Round(Clamp01(value) * (frames-1))` という単純な算術で、JS へそのまま移植できる
- 色キー透過（`TransparentBlt`相当）は Canvas の `getImageData`/`putImageData` でマスク色のピクセルを alpha=0 に置換すれば再現できる
- 数値ビットマップフォント描画（`uDigitRenderer.pas`）、推移グラフの line/bar 描画（`uGraphRenderer.pas:28-40`、`THistoryBuffer` を単純なローリングバッファとして模擬すればよい）も同様に単純な Canvas 描画で再現可能
- PNG/BMP はブラウザの `<img>`/`createImageBitmap` がネイティブ対応済みで自前デコーダ不要。ICO（トレイ用途、今回対象外）のみブラウザ間の対応が不安定
- バリスティックを対象外にしたことで、`uDisplayPipeline.pas` の時間ベースイージング（指数上昇・定速下降）を移植する必要が無くなり、実装量が大きく減る

**ローカルファイル入出力**:
- Chromium 系ブラウザの File System Access API（`showOpenFilePicker`/`showDirectoryPicker`）でフォルダの直接読み書きが可能
- ただし Chromium は `file://` から開かれたページに対してこの API を明示的にブロックする（Secure Context 判定とは別の file:// 固有の制限）。**この制約は影響範囲が限定的で回避コストも低い**: 読み込みは `<input type="file" webkitdirectory>` やドラッグ&ドロップで代替でき、これらは `file://` でも制限なく動作する。保存側も `<a download>` の Blob ダウンロードにフォールバックすれば機能は完全に維持できる（配置場所を手動で `assets/<skin>/` に戻す一手間が増えるだけ）。実装は「File System Access API が使えるときは使い、使えなければ input/drag&drop＋ダウンロードにフォールバック」という定型パターンで数十行程度

**配置場所（`assets/` でも `tools/` でもなく新規 `skin-editor/`）**:
- `uDisplayModes.LoadDisplayModes`（[uDisplayModes.pas:75-135](../src/view/uDisplayModes.pas#L75-L135)）は `assets/` 直下の**サブフォルダ全部**を表示モード候補として走査し、`layout.cfg` が無ければ `Continue` で黙ってスキップする。現状のこの緩い実装では `assets/tools/` を置いても実害は無いが、`docs/PLANNED-3.1.2.md` 項目2（assets 読み込みの堅牢化）で**まさに同じ読み込み経路の事前検証を厳格化する**ため、将来「layout.cfg の無いサブフォルダをどう扱うか」の判断が変わる余地がある。エディタを `assets/` の外に出せば、この結合を構造的に無くせる
- `tools/`（`build.ps1`/`stage-dist.ps1`/`make-installer.ps1`/`refresh-internal-design.ps1` 等）は現状**開発者専用でエンドユーザーの配布物には一切含まれない**（[tools/stage-dist.ps1:36-65](../tools/stage-dist.ps1#L36-L65) がコピーするのは `DiskLED.exe`/`assets/`/`LICENSE.txt`/`public_docs/`/`styles/` のみ、`make-portable.ps1` も `dist/DiskLED/` を ZIP 化するだけでリポジトリの `tools/` 自体は見ない）。ここへエディタ（エンドユーザー向け配布物）を置くと、「開発者専用スクリプト置き場」と「エンドユーザー向け配布物」という異なる性質が1フォルダに混在する
- **`skin-editor/` を `assets/`・`styles/`・`public_docs/` と並ぶ配布対象フォルダとして新設**し、役割を「スキン内容（`assets/`）」「開発者専用ビルドスクリプト（`tools/`、配布物に含まれない）」「エンドユーザー向け配布物（`skin-editor/`、新規）」の3つにフォルダ名で分ける
- **`stage-dist.ps1` への影響**:`stage-dist.ps1` に `Copy-Item -LiteralPath (Join-Path $Root 'skin-editor') -Destination (Join-Path $Stage 'skin-editor') -Recurse -Force` 相当の1行を追加する必要がある（[tools/stage-dist.ps1:36-37](../tools/stage-dist.ps1#L36-L37) の既存パターンを踏襲）。MSIX 側のレイアウト（`docs/internal/リリース作業手順書.md`）にも `skin-editor\` を追記する

**バリデーション（記述ミスのアラート）**:
- `docs/PLANNED-3.1.2.md` 項目2（assets 読み込みの堅牢化）で設計する Delphi 側の厳格バリデーションルール（必須項目・数値範囲・色形式・enum・Graph 座標形式）を、そのまま JS 側にも同じルールで移植する
- **継続的なリスク**: 表示エンジンと同様、このバリデーションも Delphi 側（`uSkinLoader.pas`）と JS 側の**2重実装**になる。`uSkinLoader.pas` に変更が入るたびに、このエディタ側のパーサー・バリデーターも追従改修しないと「エディタでは通るのに実機では弾かれる」という信頼性の欠陥が生まれる。実装難易度そのものより、この**継続メンテナンスの負債**が最大のコスト
- 3.1.2 でルールセットが確定してから着手する方が手戻りが少ない（3.1.2 → 3.2.0 の順で自然に依存関係がある）

### ドキュメント同梱について

現状 `docs/MAINTAINING-PUBLIC-DOCS.md` の文書表には、layout.cfg 書式の説明は開発者向けの `assets/LAYOUT.md` しか無い。「assets リファレンス」「自作 assets マニュアル」はエンドユーザー向けで性質が異なるため、`public_docs/` に JA+EN 新規ペア（例 `SKIN_GUIDE.md`）として追加し、`docs/MAINTAINING-PUBLIC-DOCS.md` の文書表もあわせて更新するのが妥当。ツール本体（`skin-editor/`）とマニュアル（`public_docs/`）で置き場所の役割を分ける。

### 見積り

未検証。3.2.0 の他項目と比べても最大規模になる見込み。段階的な見積りの目安:
- 表示エンジン移植（コンパクト表示のみ、Graph 無し）: 数日
- フル表示・推移グラフのプレビュー追加: さらに数日
- ファイル入出力（File System Access API＋フォールバック）: 1〜2日
- `skin-editor/` の新設と `stage-dist.ps1`／MSIX レイアウトへのコピー手順追加: 小規模（1時間程度）
- バリデーション移植: 3.1.2 側のルール確定後に別枠
- エンドユーザー向けドキュメント（`public_docs/` JA+EN）: 別枠
- 着手前に、コンパクト表示のみの最小版でまず技術検証（スパイク）を行い、実際の工数感を掴んでから全体計画を確定するのが安全

## 7. メモリ詳細・内訳

メモリサブセクションに Working Set・スタンバイ・コミット内訳などを追加する。

- `GlobalMemoryStatusEx` で取れる情報は現状実装済み
- `NtQuerySystemInformation`（`SystemMemoryListInformation`）で Modified / Standby / Free の内訳が取れる
- ただし非公式 API（Undocumented）のため将来の互換性リスクあり。採用するか要検討

**検証結果（2026-09-04）:**

- `src/metrics/uMemCollector.pas` 側は `GlobalMemoryStatusEx` と `GetPerformanceInfo` による現状値（使用率・空き・キャッシュ・コミット）のみで、Standby/Modified の区別は持っていない。実装自体は `NtQuerySystemInformation(SystemMemoryListInformation)` の呼び出しと `TMetricsSnapshot` へのフィールド追加程度で小さい
- リスクの本体は実装コストではなく「非公開 API への依存」。`docs/DESIGN.md` は他の項目（CPU パッケージ温度）を「一般権限 API では安定して取れないため出さない」として意図的に見送っており、本プロジェクトは一般権限・公式 API 優先の方針が明確。この方針との整合を優先するなら、Standby/Modified 内訳は見送るのが筋が良い
- 採用する場合でも、将来の Windows 更新で `SystemMemoryListInformation` の構造体レイアウトが変わるリスクを踏まえ、失敗時は既存フィールドのみ表示するフォールバックが必須
- 採用するかどうかは非公開 API 使用の可否について方針判断が要る

## 8. アクセスされているファイル（リソースモニタ相当）

どのプロセスがどのファイルにアクセスしているかを表示する。

- リソースモニタは ETW（Event Tracing for Windows）のカーネルプロバイダー（`Microsoft-Windows-Kernel-File`）を使用
- カーネルプロバイダーの有効化に**管理者権限が必要**なため、現状の一般権限前提とは相性が悪い
- ミニフィルタードライバーを使えば権限問題は解決できるが、ドライバー署名・インストールが必要になり配布コストが大幅に増加
- 3.x の配布方針（インストーラー / ポータブル / Store）とは合わない可能性が高い。将来の上位版として位置づけ

**検証結果（2026-09-04）:**

- `docs/DESIGN.md` 1 節の目的に「管理者権限なし・単一起動」が明記され、5 節「計測（Collectors）」も「いずれも管理者不要の API を優先」が原則。ETW カーネルプロバイダーの有効化（管理者権限必須）はこの中核方針と正面から矛盾する
- ミニフィルタードライバー案は権限要件こそ解決するが、ドライバー署名（EV 証明書等）・カーネルモード実装・インストール／アンインストール手順が新たに必要になり、現行の「インストーラー（ユーザー権限）／ポータブル／Store」という配布形態全体の見直しを伴う。実装規模はこれまでの機能追加とは桁が異なる
- 現行 3 配布形態のいずれとも相性が悪いため、通常版のロードマップには乗せず、ドキュメントの記載どおり「将来の上位版」（別製品・別配布ラインの検討事項）として塩漬けにするのが妥当
