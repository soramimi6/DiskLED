# ブランチ・PR 運用ルール

DiskLED は単独メンテナ・GitHub ホスト（`soramimi6/DiskLED`）・CI 無しのプロジェクト。レビュー担当がいない代わりに、PR ごとに `/code-review`（必要なら `ultra`）を通すことをレビューゲートとする。

## ブランチ構成

| ブランチ | 役割 | 寿命 |
|---|---|---|
| `master` | リリース済みの正式版。常にビルド・配布可能な状態を保つ | 恒久 |
| `feature/x.y.z` | そのバージョンの統合ブランチ。`docs/PLANNED-x.y.z.md` の全項目をここに積む | バージョン出荷まで |
| `work/x.y.z-<項番>-<要約>` | `PLANNED-x.y.z.md` の番号付き項目 1 つに対応する作業ブランチ | 対応する PR がマージされるまで |

例: `docs/PLANNED-3.1.1.md` の「5. ディスク遅延（レイテンシ）」に着手する場合 → `work/3.1.1-5-disk-latency`

`master` と `feature/x.y.z` は今までどおりの前例（`work/3.0.1` 等）を踏襲した命名。

## 通常の作業フロー

1. `feature/x.y.z` から `work/x.y.z-<項番>-<要約>` を作る
2. その項目の「実装プラン」（`PLANNED-x.y.z.md` 内）に沿って実装する
2.5. **ビルド確認**: 開発機の Delphi は Community Edition の場合 CLI ビルド不可のことがある。その場合は実装者が RAD Studio IDE で Win64 Release をビルドし、コンパイルが通ることを確認してから次へ進む（PR 前に必ず 1 回）
3. `work/...` → `feature/x.y.z` 宛てに PR を作る。説明文は対応する `PLANNED-x.y.z.md` の項番リンクのみで簡潔に（what/why の本文は squash merge 時のコミットメッセージ側が正本になるため、ここで二重に書かない）
4. `/code-review`（規模が大きい・リスクが高い項目は `/code-review ultra`）を通し、指摘を反映する
5. **squash merge** で `feature/x.y.z` に取り込み、`work/...` ブランチは削除する。GitHub の squash merge ダイアログは既定でブランチ内の各コミットメッセージを箇条書き連結するので、確定前に下記フォーマットへ手動で書き直す
6. 誤字修正やドキュメントのみの変更など、番号付き項目に対応しない軽微な修正は PR を作らず `feature/x.y.z` へ直接コミットしてよい

## リリース時（バージョン完了時）

1. `docs/PLANNED-x.y.z.md` の全項目が完了し、`public_docs/` 側の更新（CHANGELOG/USAGE/NOTES/INSTALL の JA+EN）も終わったら、`feature/x.y.z → master` の PR を作る（省略して直接 fast-forward してもよい）
2. マージは **squash しない**（Rebase and merge、または fast-forward）。項目ごとに squash 済みの履歴をそのまま `master` に残し、バージイン全体をまた 1 個のコミットに潰さない
3. マージ後、リリースタグを打つ

## コミットメッセージ

1 コミット＝ 1 まとまりの変更、という単位は維持する。フォーマットは次のとおり:

```
<Summary: 簡潔な英語、命令形、目安 50〜72 字>

<Description 日本語: 何をしたか＋なぜ（背景・目的）、1〜3 文>

<Description English: what and why, 1-3 sentences>

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
```

- **Summary** は英語のみ・簡潔に（これまでどおり）。what/why の詳細は Summary に詰め込まず Description へ回す
- **Description** は JA→EN の順で本文を書く（`docs/` が JA を正・`public_docs/EN/` を訳として置く既存の構成に合わせる）
- `Co-Authored-By:` などのトレーラーは本文の最後尾に置く
- PR を作らず `feature/x.y.z` へ直接コミットする軽微な修正（誤字・ドキュメントのみ等）は、Summary のみでよい。Description（JA+EN）は必須にしない
- 過去（〜3.1.1 時点）のコミットは Summary 1 行に what+why をまとめた旧形式。今後のコミットから新形式に切り替える（過去分の書き直しはしない）

## 備考

- CI が無いため、`/code-review` を通す・実機での目視確認（UI 変更時）を都度行うことが唯一の品質担保になる。省略しない
- `docs/PLANNED-x.y.z.md` にまだ実装プランが無い項目は、着手前にプランを詰めてから `work/...` ブランチを切る
