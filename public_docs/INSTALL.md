# インストールと配布

[English](EN/INSTALL.md)

## 対応環境

| 項目 | 要件 |
|------|------|
| OS | Windows 10 / Windows 11（64-bit） |
| 権限 | 標準ユーザーで動作（管理者不要） |
| 画面 | Per-Monitor V2。本体（ガジェット）は 0.5 刻み（125% は見た目 150%）。ダッシュボードは実 DPI。オプションは VCL の Scaled |
| ネットワーク | Ping 利用時は ICMP（エコー）が通ること。ファイアウォールで塞がれている場合はタイムアウト表示になります |

## 配布形態

| 用途 | 形態 | ファイル例 |
|------|------|------------|
| 紹介サイト・一般配布 | **インストーラー**（主配布） | `DiskLED_Setup_3.1.0.exe` |
| 上級者・開発試用 | **ポータブル zip** | `DiskLED-3.1.0-portable.zip` |

広告・バンドルソフトは同梱しません。

## インストーラー（推奨）

### インストール

1. `DiskLED_Setup_3.1.0.exe` を実行する（管理者権限は不要）
2. 既定のインストール先は `%LocalAppData%\Programs\DiskLED`
3. スタートメニューには必ず登録されます
4. **デスクトップショートカット**と**ログオン時の起動**はウィザードで選べます（どちらも**既定はオフ**）
5. 完了後、必要なら「DiskLED を起動」にチェックしたまま終了します
6. 説明書はインストール先の `public_docs` フォルダに入ります（日本語と `EN`）

### アンインストール

1. Windows の「設定」→「アプリ」→「インストールされているアプリ」（または「アプリと機能」）で **DiskLED** を選ぶ
2. 「アンインストール」を実行する

アンインストールしても、設定ファイル `DiskLED.ini`（exe と同じフォルダ、または `%AppData%\DiskLED\`）は**削除しません**。不要なら手動で消してください。スタートアップ用の Run 登録（インストール時に選んだ場合）はアンインストーラが削除します。

## ポータブル zip

1. `DiskLED-3.1.0-portable.zip` を任意のフォルダへ展開する
2. フォルダ内の `DiskLED.exe` を実行する（同梱の `assets`・`styles`・`LICENSE.txt`・`public_docs` はそのまま残す）
3. 使い終わったら DiskLED を終了し、フォルダごと削除する（`DiskLED.ini` も同フォルダにあれば一緒に消えます）

## 開発者向け: パッケージの作り方

Delphi Community Edition ではコマンドラインコンパイルができないため、先に IDE で **Win64 / Release** をビルドし、`Win64\Release\DiskLED.exe` を用意してください。ユーザー向け説明の正本はリポジトリ直下の `public_docs\` です（ステージ時に `dist\DiskLED\public_docs\` へコピーされます）。

| 手順 | コマンド（リポジトリルートで） |
|------|--------------------------------|
| ステージのみ（`dist\DiskLED\`） | `.\tools\stage-dist.ps1` |
| ポータブル zip | `.\tools\make-portable.ps1` |
| インストーラー（[Inno Setup 6](https://jrsoftware.org/isinfo.php) が必要） | `.\tools\make-installer.ps1` |

Debug ビルドしかない場合は `-Config Debug` を付けられます（配布用は Release 推奨）。
