# 3.3.1 計画

`docs/PLANNED-3.3.0.md` と同じ方針: 実ソースの `file:line` 引用で裏付け、推測で書かない。公開ドキュメント（`public_docs/`）には予定している内容は書かない。

| # | 機能 | 対応状況 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|---|
| 1 | バージョンアップ後の初回起動時、自動起動が OFF なら「Windows 起動時に DiskLED を自動起動しますか？」を尋ねる（「今後表示しない」付き） | 未着手 | 高 | 低〜中（ini キー 2 つ追加と TaskDialog 1 つ。常に手前に表示との競合対策が要る） | 1日 |

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
