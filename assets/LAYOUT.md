# layout.cfg — 表示モード定義

各表示モードは `assets/<id>/` に画像と本ファイル（INI 形式・拡張子 `.cfg`）を置きます。起動時に `layout.cfg` があるフォルダが自動登録されます（Delphi ユニット追加は不要）。アプリ設定の `DiskLED.ini` とは別物です。

## 全体構造とコンパクト／フルの独立

**コンパクトとフルは互いに一切継承しません。** タスクトレイ以外のすべての設定はコンパクト用・フル用それぞれ専用のセクションに分けて書きます。

| セクション | 内容 | コンパクト/フル |
|---|---|---|
| `[General]` | モード ID・キャプション等、コンパクト/フルによらない情報 | 共通1つ |
| `[GeneralCompact]` | コンパクトのウィンドウ定義（サイズ・背景・透過） | コンパクト専用 |
| `[GeneralFull]` | フルのウィンドウ定義。**このセクションが無ければコンパクトのみのモード**になる | フル専用（任意） |
| `[GraphFull]` | フル時のグラフ（コンパクト版は無い機能） | フル専用（任意） |
| 各パーツ節（`[CpuCompact]` 等） | 画像・座標・Ballistic・数値readout | パーツ×コンパクト/フルそれぞれ独立 |

各パーツ節は `<パーツ名>Compact` / `<パーツ名>Full`（例: `[CpuCompact]`/`[CpuFull]`、`[DiskRWCompact]`/`[DiskRWFull]`）という対称な命名です。

- 一方のセクションが無ければ、そのパーツはそのモードに単純に「存在しない」（例: `[DiskIoMeterCompact]` だけ書いて `[DiskIoMeterFull]` を書かない＝フルには出ない）
- コンパクトとフルの両方に同じパーツを出したい場合は、**両方のセクションを書く**（内容が同じでも構わない。同じ画像ファイルを指せば実素材が重複することはない）
- パーツ間・コンパクト/フル間で共有・継承する設定項目はありません。各セクションは他のセクションを見ずに単独で完結します

Original・Metalic のようにコンパクトとフルでほぼ同じパーツ配置のスキンは、その分セクションが重複して増えますが、これは意図した設計です（重複記述が増えることより、コンパクト/フルが全く異なる素材・配置・設定を持てる自由度を優先しています）。

## 透過の違い

| 対象 | キー | 意味 |
|---|---|---|
| ウィンドウ／背景 | `[GeneralCompact]`/`[GeneralFull]` の `Transparent`/`MaskColor` | カラーキー透過ウィンドウ（外形）。`Transparent=0` なら矩形窓 |
| メーター・LED・Ping・数値bitmap | 各パーツの `Transparent`/`MaskColor`（数値bitmapは `ValFontTransparent`/`ValFontMaskColor`） | **パーツ単位**の `TransparentBlt`。ウィンドウ透過とは独立 |

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

```
[General]
Id=mytheme
Caption=My Theme
Order=60
Default=0

[GeneralCompact]
Width=200
Height=32
Transparent=1
MaskColor=#FF00FF
Bg=MyTheme_Compact.png

[CpuCompact]
File=MyTheme_Cpu.png
X=4
Y=0
Frames=64
Transparent=1
MaskColor=#FF00FF
Kind=vu
Strength=55
```

## `[General]`

| キー | 内容 |
|---|---|
| Id | モード ID（省略時はフォルダ名） |
| Caption | メニュー表示名 |
| Order | メニュー並び（小さいほど上） |
| Default | `1` なら起動時の既定 |

## `[GeneralCompact]`

| キー | 内容 |
|---|---|
| Width / Height | コンパクト時のウィンドウサイズ（px）。必須 |
| Bg | コンパクト背景画像。必須 |
| Transparent | `1` でカラーキー透過ウィンドウ |
| MaskColor | `#RRGGBB`（窓の透過色／非透過時の地色） |

## `[GeneralFull]`（任意）

省略時はコンパクトのみ（ダブルクリック無効）。`Width`/`Height`/`Bg` が揃って初めてフル表示が有効になる。

| キー | 内容 |
|---|---|
| Width / Height | フル時サイズ。必須（このモードでフルを使うなら） |
| Bg | フル背景（例: `Original_FullBase.png`）。必須 |
| Transparent | `1` でカラーキー透過ウィンドウ（`[GeneralCompact]` とは独立、継承しない） |
| MaskColor | `#RRGGBB`（`[GeneralCompact]` とは独立、継承しない） |

## `[GraphFull]`（任意）

フル時のみのグラフ機能（コンパクト版という概念自体が無い）。

| キー | 内容 |
|---|---|
| Style | `line`（省略時）または `bar`。レーン共通 |
| Cpu / Mem / Swap | `X,Y,W,H`（Metalic 等）。系列は使用率 0..1 |
| DiskRead / DiskWrite / NetIn / NetOut | `X,Y,W,H`（Original 等）。系列は正規化速度 0..1 |
| *Color | `#RRGGBB`（省略時黒） |

`line` は折れ線、`bar` は下端からの幅 1px の縦棒（1 ピクセル = 1 サンプルは同じ）。値 0 は高さ 0 とし、描かない。

バッファ長は有効レーンの **最大幅 W**（1 ピクセル = 1 更新）。起動時はゼロ埋め。系列は **正規化実測 0..1**（メーターのバリスティック後の表示値ではない）。各点はグラフ更新間隔のあいだに観測した **系列ごとの最大**。

## パーツ節

19種、それぞれ `<パーツ名>Compact`/`<パーツ名>Full` の対称な名前で書く:

`Cpu` `Mem` `Swap` `Ping` `DiskRead` `DiskWrite` `DiskRW` `NetIn` `NetOut` `NetActivity` `NetTotal` `DiskReadMeter` `DiskWriteMeter` `DiskIoMeter` `NetInMeter` `NetOutMeter` `NetIoMeter` `Audio` `AudioL` `AudioR`

### 共通キー

| キー | 内容 |
|---|---|
| File | 画像（空なら未使用） |
| X / Y | 描画位置 |
| Frames | 縦方向のコマ数 |
| Transparent | パーツ透過（省略時は MaskColor があれば ON） |
| MaskColor | パーツの透過色 `#RRGGBB` |

### Ballistic キー（メーター系12種のみ・必須）

`Cpu` `Mem` `Swap` `DiskReadMeter` `DiskWriteMeter` `DiskIoMeter` `NetInMeter` `NetOutMeter` `NetIoMeter` `Audio` `AudioL` `AudioR` は、アナログ／速度メーターの追従設定として `Kind=`/`Strength=` を**必須**で書く（`File` が空でない＝実際に使うパーツの場合のみ）。共通デフォルトという概念は無く、各パーツが自分の分を必ず書く。LED 系・`Ping` には無関係（書いても読まれない）。

| キー | 内容 |
|---|---|
| Kind | プロファイル `vu` / `bar` / `peak` |
| Strength | 上昇強度 0–100（大きいほど速く追いつく。下降速度はプロファイル固定） |

| プロファイル | 想定 | 上昇（Strength 50） | 下降 |
|---|---|---|---|
| `vu` | コマ数多めの針 | 指数・やや速 | フルスケール約 0.8 秒 |
| `bar` | 粗い LED バー | 指数・中 | フルスケール約 0.5 秒 |
| `peak` | スパイク用 | 指数・最速 | フルスケール約 1.3 秒 |

上昇は指数、下降は定速スルーレート。経過時間ベースなので表示 fps を変えても時間あたりの動きは揃う。

### パーツごとの意味

- `DiskRW`: Disk Read **または** Write で点灯
- `NetTotal`: Net In **または** Out で点灯（`NetActivity` と同条件・別スプライト）
- `DiskIoMeter` / `NetIoMeter`: Disk Read/Write・Net In/Out をそれぞれ `Max()` 合成した単一メーター（コンパクト表示など、方向別に分けず1本にまとめたい場合に使う）
- `Audio` / `AudioL` / `AudioR`: 再生ピーク 0..1（MONO＝全チャンネル最大、L＝ch0、R＝ch1）。CPU メーターと同じ縦ストリップ。`File` が空なら描かない。同梱では Info Bar が `AudioL` / `AudioR` を使用（Original / Crystal / Metalic は未使用）
- `Ping` Frames=4: Timeout → Slow → Fair → Normal（上から 0..3）

画像は縦ストリップ（上から低→高）を想定しています。

### 数値readout（`[CpuCompact]`/`[CpuFull]`・`[MemCompact]`/`[MemFull]`・`[SwapCompact]`/`[SwapFull]` のみ）

パーツ節自体に以下のキーを追加すると、そのパーツの上に数値（%）を重ねて描画できる。

| キー | 内容 |
|---|---|
| ValSW | `1` で有効 |
| ValStyle | `bitmap`（省略時） / `system` |
| ValX / ValY | 描画始点 |
| ValB | 桁数 |
| ValFZ | `1`＝ゼロ埋め、`0`＝空白で右詰め |

#### bitmap

このパーツ自身が使うフォント画像（横 11 セル: 0–9・空白）を指定する。**モード共通のフォントという概念は無く、`ValStyle=bitmap` を使うパーツごとに個別指定が必須**（同じ画像ファイルを複数パーツで指せば実素材は重複しない）。

| キー | 内容 |
|---|---|
| ValFontFile | フォント画像ファイル名。必須（`ValStyle=bitmap` のとき） |
| ValFontMaskColor | 任意。指定時のみフォントを透過描画 |

#### system（GDI）

| キー | 内容 |
|---|---|
| ValFont | フォント名（欠落時は描画スキップ） |
| ValFontSize | ポイントサイズ |
| ValColor | `#RRGGBB`（省略時黒） |
| ValBold | `0`/`1` |

値は表示状態 0..1 → 四捨五入 0–100%。現状どの同梱モードも `system` は未使用（実装済み）。
