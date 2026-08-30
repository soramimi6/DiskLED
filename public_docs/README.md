# DiskLED 3 — 公開ドキュメント

[English](EN/README.md)

Windows デスクトップ常駐のシステムモニターです。CPU・メモリ・ディスク・ネットワークの「今」と、Ping による到達性を一目で確認できます。

旧 DiskLED（2.x / Windows XP 時代）を、Windows 10 / 11 向けに基本設計から再構築したシリーズです。

| 項目 | 内容 |
|------|------|
| 名称 | DiskLED |
| 想定バージョン | 3.1.0（3.x 系列） |
| 対応 OS | Windows 10 / 11（64-bit） |
| 言語 | 既定は英語。OS UI が日本語のときだけ日本語 |
| 権限 | 管理者権限は不要 |
| 公式サイト | [https://mg6.jp/](https://mg6.jp/) |
| 連絡先 | [sw@mg6.jp](mailto:sw@mg6.jp) |
| ライセンス | 公式インストーラー／ポータブル zip は無償利用可。ソースの改変・再配布は不可。詳細は同梱の `LICENSE.txt`（著作権: SoRaMiMi） |

## ドキュメント一覧

| 文書 | 内容 |
|------|------|
| [FEATURES.md](FEATURES.md) | 機能・表示モード・監視対象 |
| [USAGE.md](USAGE.md) | 起動・操作・メニュー |
| [INSTALL.md](INSTALL.md) | インストール／アンインストール／配布形態 |
| [NOTES.md](NOTES.md) | 注意事項・旧版との違い・非対応機能 |
| [CREDITS.md](CREDITS.md) | クレジット・謝辞 |
| [CHANGELOG.md](CHANGELOG.md) | 変更履歴 |

開発者向けの設計・同期ルールはリポジトリ直下の `README.md`・`docs/DESIGN.md`・`docs/MAINTAINING-PUBLIC-DOCS.md` を参照してください。

## ひとことで言うと

ハードディスクランプや NIC のアクセスランプの代わりに、デスクトップ上で負荷と転送の様子を眺めるための常駐ガジェットです。
