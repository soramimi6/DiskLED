# 3.4.0 以降 検討中（未確定）

`docs/PLANNED-3.3.0.md` と同じ方針: 実装するか・どう組み込むかは着手時に詰める。実ソースの `file:line` 引用で裏付け、推測で書かない。公開ドキュメント（`public_docs/`）には予定している内容は書かない。

| # | 機能 | 対応状況 | 実現可能性 | 難易度 | 工数目安 |
|---|---|---|---|---|---|
| 1 | PDH の型・API 宣言を共通ユニットにまとめる（収集ユニット 6 本の重複解消） | 未着手 | 高 | 低（宣言の移動のみ。動作は変えない） | 0.5日 |
| 2 | CPU 使用率のフレームごとの取得を軽くする（PDH を毎フレーム集めない） | 未着手 | 高 | 低〜中（値の見え方をタスクマネージャーと照合し直す） | 0.5〜1日 |

**優先順位の理由:**
- **1**: 動作を変えない整理で、以降の収集ユニットの修正の土台になるため先に片付ける。
- **2**: 値の算出を変えるため、1 の後に単独で照合する。

## 1. PDH の型・API 宣言を共通ユニットにまとめる

### 現状（実ソース確認済み）

- `TPdhFmtCounterValue` 型と `PdhOpenQueryW`／`PdhAddEnglishCounterW`／`PdhCollectQueryData`／`PdhGetFormattedCounterValue` などの外部関数宣言が、収集ユニットごとに同じ内容で書かれている: [uCpuCollector.pas:110](../src/metrics/uCpuCollector.pas#L110)、[uDiskCollector.pas:107](../src/metrics/uDiskCollector.pas#L107)、[uGpuCollector.pas:94](../src/metrics/uGpuCollector.pas#L94)、[uDriveCollector.pas:62](../src/metrics/uDriveCollector.pas#L62)、[uMemCollector.pas:97](../src/metrics/uMemCollector.pas#L97)、[uProcessCollector.pas:220](../src/metrics/uProcessCollector.pas#L220)。
- 定数 `PDH_FMT_NOCAP100` も 2 か所で定義している（[uCpuCollector.pas:82](../src/metrics/uCpuCollector.pas#L82)、[uProcessCollector.pas:167](../src/metrics/uProcessCollector.pas#L167)）。

### 方針

- 新規 `src/metrics/uPdhApi.pas` に、型・定数・外部関数宣言をまとめ、各収集ユニットは `uses` で参照する。`DiskLED.dpr`／`DiskLED.dproj` に追加する。
- 各ユニット固有の型（`uMemCollector` の `TPdhRawCounter` など）も、PDH の API 型であれば共通ユニットへ移す。

### 実機で見ること

- ダッシュボードの全カード・プロセスページ・ドライブ別トレイ LED の値が変更前と同じであること（動作は変えない）。

## 2. CPU 使用率のフレームごとの取得を軽くする

### 現状（実ソース確認済み）

- メーター用の CPU 使用率は、毎フレーム PDH `\Processor Information(_Total)\% Processor Utility` を集めて読んでいる（[uCpuCollector.pas:329](../src/metrics/uCpuCollector.pas#L329)）。インスタンスは `_Total` だけだが、PDH はオブジェクト全体（コアごとの全インスタンス）を計算するため、コア数が多いほど 1 回の処理が重くなる。UI スレッドのタイマーで動く。
- 1 秒ごとの数値用には別のクエリで同じカウンタを集めており（[uCpuCollector.pas:389](../src/metrics/uCpuCollector.pas#L389)）、稼働時間（`GetSystemTimes`）も 1 秒ごとに取っている（[uCpuCollector.pas:371](../src/metrics/uCpuCollector.pas#L371)）。
- プロセスページの収集も同じオブジェクトを別に集めている（[uProcessCollector.pas:185](../src/metrics/uProcessCollector.pas#L185)）。

### 方針

- フレームごとの値は `GetSystemTimes` の稼働率に戻し、1 秒ごとのクエリで求めた「`% Processor Utility` ÷ 稼働率」の比を掛けてタスクマネージャーの基準に合わせる。PDH を集めるのは 1 秒に 1 回だけにする。

### 実機で見ること

- CPU メーターと数値が、同じ時刻のタスクマネージャーとおおむね一致すること（3.3.0 の照合と同じ手順）。
- 高い fps 設定でもガジェットの描画が引っかからないこと。
