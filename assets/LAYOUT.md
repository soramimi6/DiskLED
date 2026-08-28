# layout.cfg — 表示モード定義

各表示モードは `assets/<id>/` に画像と本ファイル（INI 形式・拡張子 `.cfg`）を置きます。起動時に `layout.cfg` があるフォルダが自動登録されます（Delphi ユニット追加は不要）。アプリ設定の `DiskLED.ini` とは別物です。

## 透過の違い

| 対象 | キー | 意味 |
|---|---|---|
| ウィンドウ／背景 | `[Mode] Transparent` / `MaskColor` | カラーキー透過ウィンドウ（外形）。`Transparent=0` なら矩形窓 |
| メーター・LED・Ping・数値 bitmap | 各パーツの `Transparent` / `MaskColor` | **パーツ単位**の `TransparentBlt`。ウィンドウ透過とは独立 |

## 例

```
assets/
  original/
    layout.cfg
    Original_Base.png
    Original_Meters.png
    ...
  mytheme/
    layout.cfg
    ...
```

## [Mode]

| キー | 内容 |
|---|---|
| Id | モード ID（省略時はフォルダ名） |
| Caption | メニュー表示名 |
| Order | メニュー並び（小さいほど上） |
| Default | `1` なら起動時の既定 |
| Width / Height | コンパクト時のウィンドウサイズ（px） |
| Transparent | `1` でカラーキー透過ウィンドウ |
| MaskColor | `#RRGGBB`（窓の透過色／非透過時の地色） |
| Bg | コンパクト背景画像 |
| Font | 数値用 bitmap フォントシート（横 11 セル: 0–9・空白） |
| FontMaskColor | 任意。指定時のみフォントを透過描画 |

## [ModeFull]（任意・Phase5）

省略時はコンパクトのみ（ダブルクリック無効）。

| キー | 内容 |
|---|---|
| Width / Height | フル時サイズ |
| Bg | フル背景（例: `Original_FullBase.png`） |
| Transparent / MaskColor / Font | 省略時は `[Mode]` を継承 |

## [Graph]（フル時・任意）

| キー | 内容 |
|---|---|
| Cpu / Mem / Swap | `X,Y,W,H`（Metalic 等）。系列は使用率 0..1 |
| DiskRead / DiskWrite / NetIn / NetOut | `X,Y,W,H`（Original 等）。系列は正規化速度 0..1 |
| *Color | `#RRGGBB`（省略時黒） |

バッファ長は有効レーンの **最大幅 W**（1 ピクセル = 1 更新）。起動時はゼロ埋め。系列は **正規化実測 0..1**（メーターのバリスティック後の表示値ではない）。各点はグラフ更新間隔のあいだに観測した **系列ごとの最大**。

## [Ballistic]（任意）

アナログ／速度メーターの追従。LED と Ping は対象外。省略時は `vu` / `50`。

| キー | 内容 |
|---|---|
| Default | 既定プロファイル `vu` / `bar` / `peak` |
| Strength | 既定の上昇強度 0–100（大きいほど速く追いつく。下降速度はプロファイル固定） |
| Cpu / Mem / Swap / DiskReadMeter / DiskWriteMeter / NetInMeter / NetOutMeter | `vu` または `vu,60`（プロファイル,強度） |

| プロファイル | 想定 | 上昇（Strength 50） | 下降 |
|---|---|---|---|
| `vu` | コマ数多めの針 | 指数・やや速 | フルスケール約 0.8 秒 |
| `bar` | 粗い LED バー | 指数・中 | フルスケール約 0.5 秒 |
| `peak` | スパイク用 | 指数・最速 | フルスケール約 1.3 秒 |

上昇は指数、下降は定速スルーレート。経過時間ベースなので表示 fps を変えても時間あたりの動きは揃う。

## パーツ節

`Cpu` `Mem` `Swap` `Ping` `DiskRead` `DiskWrite` `DiskRW` `NetIn` `NetOut` `NetActivity` `NetTotal` `DiskReadMeter` `DiskWriteMeter` `NetInMeter` `NetOutMeter`

| キー | 内容 |
|---|---|
| File | 画像（空なら未使用） |
| X / Y | 描画位置 |
| Frames | 縦方向のコマ数 |
| Transparent | パーツ透過（省略時は MaskColor があれば ON） |
| MaskColor | パーツの透過色 `#RRGGBB` |

- `DiskRW`: Disk Read **または** Write で点灯
- `NetTotal`: Net In **または** Out で点灯（`NetActivity` と同条件・別スプライト）
- `Ping` Frames=4: Timeout → Slow → Fair → Normal（上から 0..3）

画像は縦ストリップ（上から低→高）を想定しています。

## 数値 Val*（`[Cpu]` / `[Mem]` / `[Swap]`）

| キー | 内容 |
|---|---|
| ValSW | `1` で有効 |
| ValStyle | `bitmap`（省略時） / `system` |
| ValX / ValY | 描画始点 |
| ValB | 桁数 |
| ValFZ | `1`＝ゼロ埋め、`0`＝空白で右詰め |

### bitmap（`[Mode] Font`）

Mode 共通のフォント画像を切り出して描画。`FontMaskColor` があれば透過。

### system（GDI）

| キー | 内容 |
|---|---|
| ValFont | フォント名（欠落時は描画スキップ） |
| ValFontSize | ポイントサイズ |
| ValColor | `#RRGGBB`（省略時黒） |
| ValBold | `0`/`1` |

値は表示状態 0..1 → 四捨五入 0–100%。現状どの同梱モードも `system` は未使用（実装済み）。
