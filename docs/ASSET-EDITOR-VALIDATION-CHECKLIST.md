# asset-editor 検証チェックリスト（人力照合用）

`docs/PLANNED-3.2.0.md` 項目6のスコープ確定事項「2重実装の扱い」に基づく運用ドキュメント。CI が無いため、`src/view/uSkinLoader.pas`（Delphi 側の検証ロジック）と `asset-editor/js/skinLoader.js`（JS 側の同等実装）の整合性は、このチェックリストで人力照合する。

## 運用ルール

- **`uSkinLoader.pas` の `Read*` 系ヘルパー（`ReadStrictInt`/`ReadStrictBool`/`ReadStrictColor`/`ReadSprite`/`ReadMeterSprite`/`ReadDigitValue`/`ReadGraphLane`/`LoadSkinLayout`）に変更を加えたら、`asset-editor/js/skinLoader.js` の対応するロジックも追従改修すること。**
- 改修後は、このチェックリストの全項目を **実機（RAD Studio ビルドした DiskLED.exe）** と **asset-editor（ブラウザ）** の両方で再実行し、期待結果と一致するか確認する。
- 不一致が見つかったら `asset-editor/js/skinLoader.js` を修正し、必要なら本チェックリストの期待結果・fixture 自体も更新する。
- fixture は `tools/asset-editor-fixtures/<番号>-<名前>/layout.cfg` に置く（開発者専用、配布物には含まれない — `tools/` の既存方針どおり）。
- fixture の `File=`/`Bg=` が指す画像は実在しない（検証ロジックはファイル存在を見ないため無関係）。asset-editor 側でプレビュー時に「画像未取り込み」の赤枠が出るのは想定どおりで、このチェックリストが確認したい検証結果ではない。

## 確認手順

**asset-editor 側**:
1. `asset-editor/index.html` を開く
2. 「Load asset folder…」で対象 fixture のフォルダ（`tools/asset-editor-fixtures/<番号>-<名前>/`）を直接選択
3. 「期待結果（JS）」欄と実際の挙動（`editError` のエラーメッセージ、または警告ボックスの有無）を照合

**DiskLED.exe 側**:
1. fixture の `layout.cfg` を一時的に `assets/<fixture名>/layout.cfg` としてコピー
2. RAD Studio で Win64 Release をビルドし、DiskLED.exe を起動
3. スキン選択で fixture を選び、起動時エラー（あれば）を確認
4. 確認後、コピーした fixture フォルダを削除する（`assets/` に残さない）

## チェック項目

JS側の列は本チェックリスト作成時に `node` 上で `skinLoader.js` を実行し確認済み（2026-09-13）。Delphi側の列は実機ビルドでの確認が必要（CE エディションのため CLI 実行不可、RAD Studio IDE での手動確認のみ）。

| # | Fixture | 検証対象 | 期待結果（両側共通） | JS側 確認結果 | Delphi側 確認 |
|---|---|---|---|---|---|
| 1 | `01-valid-minimal` | 正常系（最小構成） | エラー無し | ✅ OK | ☐ |
| 2 | `02-missing-mode-field` | `GeneralCompact` の `Height` 欠落 | エラー（`err.layout_mode_incomplete` 相当） | ✅ `[GeneralCompact] is incomplete` | ☐ |
| 3 | `03-invalid-int` | `X=abc`（整数でない） | エラー | ✅ `X=abc is not a valid value` | ☐ |
| 4 | `04-invalid-bool` | `Transparent=maybe`（真偽値でない） | エラー | ✅ `Transparent=maybe is not a valid value` | ☐ |
| 5 | `05-invalid-color` | `MaskColor=notacolor`（色形式でない） | エラー | ✅ `MaskColor=notacolor is not a valid value` | ☐ |
| 6 | `06-frames-zero` | `Frames=0`（1未満） | エラー | ✅ `Frames=0 is not a valid value` | ☐ |
| 7 | `07-meter-missing-ballistic` | メーターパーツに `Kind`/`Strength` が無い | エラー（`err.layout_ballistic_required` 相当） | ✅ `Kind/Strength=(missing) is not a valid value` | ☐ |
| 8 | `08-invalid-ballistic-kind` | `Kind=triangle`（bar/peak/vu以外） | エラー | ✅ `Kind=triangle is not a valid value` | ☐ |
| 9 | `09-strength-out-of-range` | `Strength=150`（0〜100の範囲外） | エラー | ✅ `Strength=150 is not a valid value` | ☐ |
| 10 | `10-digit-missing-font` | `ValSW=1`+`ValStyle=bitmap`で`ValFontFile`無し | エラー（`err.layout_digit_font_required` 相当） | ✅ `ValFontFile=(required...) is not a valid value` | ☐ |
| 11 | `11-digit-invalid-b` | `ValB=0`（1未満） | エラー | ✅ `ValB=0 is not a valid value` | ☐ |
| 12 | `12-graph-invalid-lane` | `[GraphFull] Cpu=1,2,3`（4要素でない） | エラー | ✅ `Cpu=1,2,3 is not a valid value` | ☐ |
| 13 | `13-duplicate-key` | `X` キーが2回定義されている | ⚠️ 未確定（下記「既知の未解決事項」参照） | ✅ エラー無し・重複キー警告「X」を検出 | ☐ **要確認: どちらの値が採用されるか** |
| 14 | `14-unknown-key` | `FooBar` という未知のキーが存在 | エラー無し（Delphi側は単に無視される想定） | ✅ エラー無し・不明キー警告「FooBar」を検出 | ☐ |
| 15 | `15-valid-full-with-graph` | 正常系（Compact+Full+Graph+数値readout+LED+Ping の網羅） | エラー無し | ✅ OK（hasFull=true） | ☐ |

## 既知の未解決事項

- **fixture 13（重複キー）の Delphi 側の実際の挙動が未確認。** `asset-editor/js/cfgModel.js` の `CfgDoc` は「先勝ち（最初の出現を採用）」を明示的な方針としているが、Delphi の `TMemIniFile.ReadString` が重複キーに対して実際に先勝ちか後勝ちかは、VCL ソースを読むか実機で確認するまで確定していない。**実機確認で後勝ちだと判明した場合、`CfgDoc` の重複解決方針をどちらに揃えるか（あるいは「重複はエラーとして扱い、読み込み自体を拒否する」方針に変更するか）を検討する必要がある。** 現状は「重複はGUIエディタ側で警告するのでユーザーが直す」という前提で先勝ち・後勝ちのどちらでも致命的ではないという判断だが、両実装が異なる値を採用してしまう状態は望ましくないため、次回このチェックリストを実施する際に解消すること。
