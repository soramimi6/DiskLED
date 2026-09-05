# 3.1.2 予定（未実装）

公開ドキュメント（`public_docs/`）には予定している内容は書かない。実装が入り、利用者に見えるようになってから CHANGELOG（JA+EN）へ「実装済み」として書く。

3.1.1 は Microsoft Store の認定へ提出済みのため、以降に見つかった変更はこの 3.1.2 に積む。

## 1. Dashboard ウィンドウの画面外復帰

**モニター構成の変更（サブモニター取り外し等）で、Dashboard ウィンドウが画面外に出て操作できなくなる不具合を修正する。**

3.1.1 の実機最終検証で発見。メインウィンドウ（ガジェット本体）には既に画面内補正の仕組みがあるが、Dashboard には無い。

### 現状の確認結果

- メインウィンドウは `TMainForm.ApplyWindowBounds`（[uMainForm.pas:787](../src/uMainForm.pas#L787)）が `Self.BoundsRect` を `ConstrainAndSnapRect`（[uWindowPlacement.pas:127](../src/uWindowPlacement.pas#L127)）で画面内へ補正しており、右クリックの「位置をリセット」（`TMainForm.miResetPositionClick`、[uMainForm.pas:1099](../src/uMainForm.pas#L1099)）から手動でも呼べる
- Dashboard（`TDashboardForm`）は `ApplySavedDipBounds`（[uDashboardForm.pas:237](../src/dashboard/uDashboardForm.pas#L237)）が保存済みの `DashboardX/Y/W/H` をそのまま `SetBounds` するだけで、画面内チェックが一切無い。`FormCreate`（[uDashboardForm.pas:119](../src/dashboard/uDashboardForm.pas#L119)）内で最初の表示時にしか呼ばれない
- `TMainForm.ShowDashboard`（[uMainForm.pas:704](../src/uMainForm.pas#L704)）は `FDashboardForm` を一度だけ生成して使い回す（`.Create` は初回のみ、以降は `.Show` のみ）ため、`FormShow`（[uDashboardForm.pas:547](../src/dashboard/uDashboardForm.pas#L547)）は非表示→表示の遷移のたびに毎回呼ばれる
- `miResetPositionClick` はメインウィンドウの `BoundsRect` しか触っておらず、Dashboard には波及しない
- Ping 結果表示（`TTraceRouteForm`）は位置を保存せず毎回 `Position := poScreenCenter`（[uTraceRouteForm.pas:105](../src/uTraceRouteForm.pas#L105)）のため対象外（画面外に残る問題がそもそも起きない）

### 実装プラン（決定事項）

- **表示のたびの画面内補正**: `TDashboardForm.FormShow` に、`WindowState = wsNormal` のときだけ `BoundsRect` を画面内へ補正する処理を追加する。ドラッグ中の追従・スナップは不要（メイン側と違い常時ドラッグ制約を扱っている最中の枠ではないため、表示タイミングの一度きりでよい）。既存の `ConstrainAndSnapRect` をそのまま使うか、エッジスナップ無しの `ClampRectToWindowMonitor`（[uWindowPlacement.pas:137](../src/uWindowPlacement.pas#L137)）を使うかは実装時に決める（Dashboard は枠付きの通常ウィンドウでスナップ挙動は不要な可能性が高く、後者が有力）
- **「位置をリセット」からの波及**: `TMainForm.miResetPositionClick` に、`FDashboardForm <> nil` のときだけ Dashboard 側にも同じ画面内補正をかける呼び出しを追加する。Dashboard 側に `TMainForm.ApplyWindowBounds` 相当の公開メソッドを新設し、呼び出し後は `PersistDashboardDip`（[uDashboardForm.pas:252](../src/dashboard/uDashboardForm.pas#L252)）＋設定保存で新しい位置を残す
- Ping 結果表示は対象外（現状のままでよい）

見積り: 半日未満（小規模）。
