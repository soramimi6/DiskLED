# 3.3.1 計画

`docs/PLANNED-3.3.0.md` と同じ方針: 実ソースの `file:line` 引用で裏付け、推測で書かない。公開ドキュメント（`public_docs/`）には予定している内容は書かない。

| # | 機能 | 対応状況 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|---|
| 1 | バージョンアップ後の初回起動時、自動起動が OFF なら「Windows 起動時に DiskLED を自動起動しますか？」を尋ねる（「今後表示しない」付き） | 完了 | 高 | 低〜中（ini キー 2 つ追加と TaskDialog 1 つ。常に手前に表示との競合対策が要る） | 1日 |
| 2 | ドライブ別トレイ LED の見た目を直す（ライトモードでドライブレターが読めない／LED の縁がギザギザ） | 完了 | 高 | 低（`uTrayIconComposer.pas` 1 ファイルの描画処理） | 0.5日 |

## 1. バージョンアップ後の初回起動時に自動起動を尋ねる

### 現状（実ソース確認済み）

- 自動起動はどの配布形態でも初期状態が OFF。インストーラー版はタスクが未チェック（[DiskLED.iss:47](../installer/DiskLED.iss#L47)）、zip 版は ini の既定値が `False`（[uSettings.pas:292](../src/uSettings.pas#L292)）、Store 版はマニフェストの起動タスクが `Enabled="false"`（[AppxManifest.xml:49](../packaging/msix/AppxManifest.xml#L49)）。
- ini には前回起動したバージョンを記録していない。`[General]` に書くのは `StayOnTop`／`Startup` など（[uSettings.pas:515-519](../src/uSettings.pas#L515-L519)）。
- 実行中のバージョンは `GetProductVersionText` で取れる（[uAppStrings.pas:393](../src/uAppStrings.pas#L393)）。
- `TAppSettings.Load` は ini が無いと既定値のまま抜ける（[uSettings.pas:412-416](../src/uSettings.pas#L412-L416)）。`FormCreate` の途中で `PersistSettings` が ini を書き出す（[uMainForm.pas:413](../src/uMainForm.pas#L413)）ため、「ini が元々あったか」は `Load` の時点で記録しておく必要がある。
- ini の置き場所は exe と同じフォルダが優先、書き込めなければ `%APPDATA%\DiskLED`（[uSettings.pas:330-350](../src/uSettings.pas#L330-L350)）。
- インストーラー版と zip 版は同じ exe で、実行時に見分ける仕組みは無い。Store 版だけは `IsStorePackage` で判別できる（[uPackaging.pas:40](../src/uPackaging.pas#L40)）。インストーラーのインストール先 `{app}` には Inno Setup が `unins000.exe` を置く（[DiskLED.iss:22](../installer/DiskLED.iss#L22)）。
- 自動起動の状態は `TStartup.QueryState` で 1 回読める（Store 版は WinRT、それ以外は Run キー。[uStartup.pas:377](../src/uStartup.pas#L377)）。ON にするのは `TStartup.SetRegistered(True)`（[uStartup.pas:369](../src/uStartup.pas#L369)）。Store 版の `RequestEnableAsync` は投げっぱなしで、初回は Windows の同意プロンプトが出ることがある（[uStartup.pas:337-343](../src/uStartup.pas#L337-L343)）。
- `FormCreate` の中で WinRT を呼ぶと起動が止まる恐れがあるため避けている（[uMainForm.pas:344-348](../src/uMainForm.pas#L344-L348)）。
- 「トレイのみ」設定ではメインウィンドウを出さずに起動する（[uMainForm.pas:355-356](../src/uMainForm.pas#L355-L356)）。
- 「常に手前に表示」では `PollStayOnTop` がメインウィンドウを定期的に `HWND_TOPMOST` へ戻す。オプション画面を開いている間は `FOptionsOpen` で止めている（[uMainForm.pas:113-117](../src/uMainForm.pas#L113-L117)、[uMainForm.pas:821](../src/uMainForm.pas#L821)、[uMainForm.pas:1535-1539](../src/uMainForm.pas#L1535-L1539)）。
- 前回ダッシュボードを開いたまま終了していると、起動時に開く（[uMainForm.pas:432-433](../src/uMainForm.pas#L432-L433)）。
- 既存の確認ダイアログは `MessageBox`（[uOptionsForm.pas:569](../src/uOptionsForm.pas#L569)）で、チェックボックスを付けられない。

### 方針

**ini キー（`[General]`）**
- `LastRunVersion`（文字列）: 前回起動したバージョン。起動のたびに現在のバージョンで上書きする。
- `StartupPromptDisabled`（真偽値）: 「今後表示しない」。既定は `False`。
- `TAppSettings` に「ini が読み込み時点で存在したか」を持たせ、`Load` で設定する。

**尋ねる条件（すべて満たすときだけ）**
1. ini が元々あった（無い＝クリーンインストールでは尋ねない）。
2. `LastRunVersion` が現在のバージョンと違う（キーが無い＝3.3.0 以前からの更新も含む）。
3. `StartupPromptDisabled` が `False`。
4. インストーラー版ではない（対象は zip 版と Store 版）。Store 版は `IsStorePackage` で先に判定し、それ以外は exe と同じフォルダに `unins000.exe` があればインストーラー版とみなす。
5. メインウィンドウが表示されている（`WindowHidden` が `False`）。「トレイのみ」のときは尋ねない。
6. `TStartup.QueryState` が「OFF・Windows 側で無効化されていない・状態取得に成功」を返す。

条件 1〜3 に当てはまれば、尋ねたかどうかにかかわらず `LastRunVersion` を更新する。尋ねる機会は 1 バージョンにつき 1 回までで、条件 5 で見送った場合もその版ではもう尋ねない。

**表示のタイミング**
- `FormCreate` の末尾で独自メッセージ（`WM_APP` 系）を `PostMessage` する。`Application.Run` のメッセージループが始まってから受け取り、そこで条件 6 の `QueryState` と表示を行う。ダッシュボードはそれより前に開くため、ダイアログが後から前面に出る。

**ダイアログ**
- Windows 標準の TaskDialog（VCL の `TTaskDialog`）を使う。所有者はメインウィンドウにする。
  - 位置: ガジェットがあるモニターの作業領域の中央（`OnDialogConstructed` で移動する）。×／Esc で閉じたときは「いいえ」と同じ扱い。
  - 本文: 「Windows 起動時に DiskLED を自動起動しますか？」
  - ボタン: 「はい」「いいえ」
  - チェックボックス（verification）: 「今後表示しない」
- 表示中は `FOptionsOpen` と同じ扱いで `PollStayOnTop` を止める。フラグを共通化するか別フラグを足すかは実装時に決める。
- 「はい」: `TStartup.SetRegistered(True)`。Store 版ではこのあと Windows の同意プロンプトが出ることがあり、それはそのまま許容する。Store 版以外では `FSettings.Startup := True` にしてから保存する。
- 「今後表示しない」にチェックがあれば `StartupPromptDisabled := True` を保存する（「はい」「いいえ」どちらでも）。
- 文字列は `uAppStrings` に JA/EN で追加する。

**既知の制限**
- zip 版を新しいフォルダに展開して更新した場合、ini が exe と同じフォルダにあると新しいフォルダには ini が無いので、クリーンインストールと同じ扱いになり尋ねない。上書き展開や `%APPDATA%` に ini がある場合は尋ねる。

### 実機で見ること

各ケースで、Options の「スタートアップに登録」を OFF にしたうえで、ini の `LastRunVersion` を消す（または古い値にする）と「バージョンアップ後の初回起動」を再現できる。

- **zip 版・通常表示**: 起動直後にダイアログが出て、メインウィンドウより前面にある。「はい」で Options の「スタートアップに登録」が ON になり、Run キーに `DiskLED` が書かれる。
- **再起動**: 同じバージョンのまま再起動するとダイアログが出ない。
- **今後表示しない**: チェックして閉じたあと、`LastRunVersion` を消して再起動してもダイアログが出ない。
- **常に手前に表示 ON**: ダイアログがガジェットの下に埋もれず、10 秒以上待っても前面のまま。
- **トレイのみ**: ダイアログが出ない。
- **起動時にダッシュボードが開く設定**: ダッシュボードが開いたあと、ダイアログがその前面に出る。
- **インストーラー版**（`unins000.exe` あり）: ダイアログが出ない。
- **クリーンインストール**（ini が無い）: ダイアログが出ない。
- **自動起動が既に ON**: ダイアログが出ない。
- **Store 版**: 「はい」のあとに Windows の同意プロンプトが出た場合も、自動起動が ON になる（Options の表示とタスクマネージャーの「スタートアップ アプリ」で確認）。タスクマネージャーで無効化している場合はダイアログが出ない。
- **表示**: DPI 100／125／150／200%、Windows のライト／ダーク、JA／EN で文字が欠けない。

## 2. ドライブ別トレイ LED の見た目を直す

Windows のライトモードでは、ドライブ別トレイ LED のドライブレターが背景に溶けて読めない。また、ドライブ別 LED はネットワーク LED より円の縁がギザギザに見える。

### 現状（実ソース確認済み）

- ドライブ別のトレイアイコンは、`assets/tray/<色>/diskOff.ico`・`diskOn.ico` を小アイコンサイズで読み込み（[uMainForm.pas:1193-1196](../src/uMainForm.pas#L1193-L1196)）、`SyncDriveTrays` で `ComposeLetterIcon` を通してドライブレターを重ねたものを使う（[uMainForm.pas:1360-1361](../src/uMainForm.pas#L1360-L1361)）。
- ネットワーク LED（と主 LED）は読み込んだアイコンをそのままトレイに渡す（[uMainForm.pas:1185-1191](../src/uMainForm.pas#L1185-L1191)、[uMainForm.pas:1241-1242](../src/uMainForm.pas#L1241-L1242)）。
- 読み込みは `LoadImage` でシステムの小アイコンサイズちょうどのコマを選ぶ（[uAssetStore.pas:180-196](../src/view/uAssetStore.pas#L180-L196)）。.ico は 16〜96px の 32bit PNG コマを持ち、16px コマでは円の縁の 49 ピクセルが半透明。
- **縁がギザギザになる原因**: `ComposeLetterIcon` は元アイコンを `TGPBitmap.Create(ABase.Handle)`（GDI+ の `Bitmap::FromHICON`）で取り込む（[uTrayIconComposer.pas:47](../src/uTrayIconComposer.pas#L47)）。この関数はアイコンのアルファチャンネルを使わず AND マスクで透過を作るため、縁の半透明ピクセルが不透明か透明かの 2 値になる。ネットワーク LED は合成を通らないので、半透明の縁がそのまま残る。
- **ドライブレターが読めない原因**: 文字は Segoe UI Bold、アイコンサイズの 0.62 倍（16px で約 10px）で（[uTrayIconComposer.pas:20](../src/uTrayIconComposer.pas#L20)、[uTrayIconComposer.pas:54](../src/uTrayIconComposer.pas#L54)）、右下隅に寄せて置く（[uTrayIconComposer.pas:62-64](../src/uTrayIconComposer.pas#L62-L64)）。このため文字の大半は LED の円の外、タスクバーの背景の上に直接乗る。塗りは白、縁取りは黒（不透明度 220/255）でサイズの 0.12 倍（16px で約 1.9px）（[uTrayIconComposer.pas:21](../src/uTrayIconComposer.pas#L21)、[uTrayIconComposer.pas:66](../src/uTrayIconComposer.pas#L66)、[uTrayIconComposer.pas:73](../src/uTrayIconComposer.pas#L73)）。小さい文字ではアンチエイリアスで縁取りが薄い灰色になり、明るい背景では白い塗りと一緒に背景へ溶ける。
- 合成結果は `Target.GetHICON` でアイコンにしている（[uTrayIconComposer.pas:86](../src/uTrayIconComposer.pas#L86)）。

### 方針

`uTrayIconComposer.pas` の `ComposeLetterIcon` だけを直す。呼び出し側と素材は変えない。

**元アイコンをアルファ付きで取り込む**
- `TGPBitmap.Create(ABase.Handle)` をやめる。`GetIconInfo` でカラービットマップを取り、`GetDIBits` で 32bit・トップダウンの DIB として読み出し、`PixelFormat32bppARGB` の `TGPBitmap` に写してから描く。
- 取り出したアルファがすべて 0 の場合（アルファを持たない古い形式のアイコン）は、マスクビットマップから透過を作る。
- `GetIconInfo` で得たビットマップ 2 つは `DeleteObject` で解放する。

**ドライブレターの後ろに暗い下地を敷く**
- 文字の外接矩形に少し余白を足した角丸の下地（黒・半透明）を、文字より先に描く。下地はアイコン内に収め、はみ出す場合は右下に寄せたまま切り詰める。
- 文字は白で塗る。下地があるので縁取りは不要か細くする。どちらにするかは 16／20／24／32px の実機表示を見て決める。
- 下地の色はライト／ダークで変えない。タスクバーの明るさに関係なく読めるので、テーマ変更を検知して作り直す処理は足さない。
- 余白・角の丸み・不透明度はサイズ比の定数にする（既存の `CLetterEmRatio`／`COutlineWidthRatio` と同じ書き方）。

### 実機で見ること

オプションの「トレイ LED」でドライブ別 LED を 2 つ以上 ON にし、ネットワーク LED も表示した状態で見る。

- **ライトモード**（設定 → 個人用設定 → 色 →「既定のアプリモード」と「既定の Windows モード」をライト）: すべてのドライブ別 LED でドライブレターが読める。点灯／消灯のどちらでも読める。
- **ダークモード**: ドライブレターが従来どおり読める。
- **縁のなめらかさ**: ドライブ別 LED の円の縁が、隣のネットワーク LED と同じなめらかさに見える（拡大鏡で比べて、ドライブ別だけが階段状になっていない）。
- **LED の色**: 4 色（緑・赤・黄・青）それぞれで上の 3 点が成り立つ。
- **DPI**: 100／125／150／200% で、ドライブレターと下地が欠けたりはみ出したりしない。DPI を変えたあとは DiskLED を再起動してから確認する。
