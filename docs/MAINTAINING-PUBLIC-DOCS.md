# 公開ドキュメントの保守

`public_docs/` はエンドユーザー向けの正本です。開発用の詳細は `README.md`（方針）と `docs/DESIGN.md`（実装設計）に置き、**ユーザーに見える差分は公開ドキュメントへ同時反映**します。

`tools/stage-dist.ps1` は正本を `dist/DiskLED/public_docs/` へコピーします。ポータブル zip と Inno Setup インストーラーは `dist/DiskLED/` 一式を梱包するため、**説明書も配布物に含まれます**。`dist/DiskLED/` はステージのたびに消えるので、編集は必ずリポジトリ直下の `public_docs/` 側で行う。

## 言語配置

| 言語 | 場所 |
|------|------|
| 日本語 | `public_docs/*.md` |
| 英語 | `public_docs/EN/*.md`（同名ファイル） |

公開本文を変えるときは **日本語と `EN/` 内の英語を同じ内容で両方更新**する。

| 日本語 | 英語 |
|--------|------|
| `README.md` | `EN/README.md` |
| `FEATURES.md` | `EN/FEATURES.md` |
| `USAGE.md` | `EN/USAGE.md` |
| `INSTALL.md` | `EN/INSTALL.md` |
| `NOTES.md` | `EN/NOTES.md` |
| `CREDITS.md` | `EN/CREDITS.md` |
| `CHANGELOG.md` | `EN/CHANGELOG.md` |

## 文書の役割

| パス | 読者 | 書いてよいこと |
|------|------|----------------|
| `public_docs/*.md` / `EN/*.md` | 利用者 | 機能・使い方・制限・クレジット。内部モジュール名は最小限 |
| `README.md`（リポジトリ根） | 開発者 | 確定方針・MVP 表（前半日本語・後半英語。日本語を変えたら英訳も同じ変更で更新） |
| `docs/DESIGN.md` | 開発者 | モジュール・API・フェーズ |
| `docs/PLANNED-3.1.1.md` | 開発者 | 3.1.1 の未実装予定。公開ドキュメントには書かない |
| `docs/Microsoft_Store.md` | オーナー | Microsoft Store の初回登録・申請内容・更新手順。GitHub には上げない |
| `docs/LISTING.md` | オーナー | 掲載サイト向け文案 |
| `docs/VECTOR.md` | オーナー | Vector（DiskLED3）の差し替え申請手順。GitHub には上げない |
| `assets/LAYOUT.md` | 開発者 | layout.cfg 書式 |

## 同期が必要な変更

次を変えたら、**同じ作業単位で** 日本語と `EN/` の対応ファイルを更新する。

| 変更内容 | 更新する公開ドキュメント（JA + EN） |
|----------|-------------------------------------|
| ユーザー向け機能の追加・削除・仕様変更 | `FEATURES` / `USAGE` / `CHANGELOG` |
| 対応 OS・権限・DPI・配布形態（zip / インストーラー） | `INSTALL` / `README` |
| メニュー項目・オプション・ini キーのユーザー影響 | `USAGE` |
| 非対応機能・注意・プライバシー | `NOTES` |
| クレジット・スキン由来 | `CREDITS` |
| リリース版の確定 | `CHANGELOG`（実装済み／未実装を整理し、版番号を切る） |

実装が設計より遅れている場合は、`CHANGELOG` の「実装済み／未実装」と `USAGE` のメニュー表を**実装に合わせて正直に**書く。製品ビジョン（MVP）は FEATURES に、現状は CHANGELOG / USAGE に分ける。

## やってはいけないこと

- 片方の言語だけ更新して、もう一方を放置する
- 公開ドキュメントだけ先行して「できる」と書き、実装も設計も無い状態を放置する
- 設計書だけ更新して `public_docs/` を忘れる
- 公開文書に内部フェーズ名（Phase0〜Phase5）やユニット名を多用する（必要なら「開発中」程度）

## チェック（PR / 作業完了前）

- [ ] ユーザー操作や表示が変わった → `USAGE` / `FEATURES`（JA+EN）を見た
- [ ] 配布の話が変わった → `INSTALL`（JA+EN）を見た
- [ ] リリースや大きな区切り → `CHANGELOG`（JA+EN）を更新した
- [ ] ルート `README.md` の方針と矛盾がない
