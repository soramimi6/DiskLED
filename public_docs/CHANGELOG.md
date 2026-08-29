# 変更履歴

[English](EN/CHANGELOG.md)

形式: 新しいものが上。ユーザー向けの要約のみ。

## 3.0.1

Windows 10 / 11 向け DiskLED 3.x の更新（64-bit）。

- 常駐負荷: 見た目のコマが変わったときだけ再描画（計測は表示 fps と同じ）
- メーター追従: 表示モードの `layout.cfg` `[Ballistic]` でプロファイル指定（vu / bar / peak）
- Original: ネット LED を送受信別（In / Out）に変更。アナログメーター 64 コマ。フル表示の推移グラフは棒
- Crystal: CPU / メモリ レベルバーを 32 コマに補間（滑らかな追従）
- Metalic: フル表示の推移グラフは折れ線（従来どおり）
- ネット速度の反応を直線（既定）と対数で切替可能（オプション）。ディスクはオートセンスの直線のみ。切替時は推移グラフをクリア
- 配布: `DiskLED_Setup_3.0.1.exe` と `DiskLED-3.0.1-portable.zip`

## 3.0.0 — MVP

Windows 10 / 11 向けの DiskLED 3.x 初版（64-bit）。旧 2.x からの再構築です。

- CPU / メモリ / SWAP / ディスク / ネット / Ping の常駐表示
- 表示モード: Original / Crystal / Metalic（フル／コンパクト切替と推移グラフは Original・Metalic）
- 単一起動、最前面、トレイ、スタートアップ、オプション、`DiskLED.ini`
- ユーザー権限インストーラー（`DiskLED_Setup_3.0.0.exe`）とポータブル zip
- UI: 既定は英語、OS UI が日本語のときだけ日本語
- 広告・バンドルソフトなし

---

## 参考: 旧系列

3.x の版数は 2.x から独立して数え直します。
