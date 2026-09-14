# スキンギャラリー

[English](EN/SKIN_GALLERY.md)

DiskLED に同梱されている5つの表示モード（スキン）の見本です。切り替え方法は [USAGE.md](USAGE.md) の右クリックメニューの節を、各項目の詳しい仕様は [FEATURES.md](FEATURES.md) を参照してください。画像はサンプル値（架空のCPU/メモリ使用率・ディスク/ネット活動）を、実際にデスクトップに表示されるのと同じ実寸（等倍）で示しています。

## Original

<img src="images/skins/original-compact.png" alt="Original（コンパクト）" width="240" height="34"><br>
<img src="images/skins/original-full.png" alt="Original（フル）" width="240" height="52">

- **由来**: System Analog Meter II（sam2）系の旧スキンを移植
- **サイズ**: コンパクト 240×34 ／ フル 240×52（左ダブルクリックで切替）
- **特徴**: アナログ針メーター。フルでは推移グラフ（棒）が追加されます
- **メーター**: CPU / メモリ / SWAP の針メーター、ディスク読み書き・ネット送受信の活動LED、同速度メーター（リキッドバー）、Ping。フルはこれに加えディスク・ネットの推移グラフ

## Crystal

<img src="images/skins/crystal-compact.png" alt="Crystal" width="192" height="14">

- **由来**: Mac OS X 風スキン（MacX）を移植
- **サイズ**: 192×14（コンパクトのみ）
- **特徴**: 同梱スキンの中で最小。フラットな棒グラフと小型LED
- **メーター**: CPU / メモリ の使用率バー、ディスク読み書き・ネット活動/送受信の活動LED、Ping

## Metalic

<img src="images/skins/metalic-compact.png" alt="Metalic（コンパクト）" width="256" height="24"><br>
<img src="images/skins/metalic-full.png" alt="Metalic（フル）" width="256" height="48">

- **由来**: xsrv SkinS/SkinL 系の旧スキンを移植
- **サイズ**: コンパクト 256×24 ／ フル 256×48（左ダブルクリックで切替）
- **特徴**: 同梱スキンの中で最も情報密度が高い。使用率バーに数値（%）を直接表示。フルでは推移グラフ（折れ線）が追加されます
- **メーター**: CPU / メモリ / SWAP の使用率バー（数値表示付き）、ディスク読み書き・統合の活動LED、ネット送受信・統合・活動の活動LED、Ping。フルはこれに加えCPU/メモリ/SWAPの推移グラフ

## Info Bar

<img src="images/skins/infobar-compact.png" alt="Info Bar（コンパクト）" width="285" height="16"><br>
<img src="images/skins/infobar-full.png" alt="Info Bar（フル）" width="531" height="16">

- **由来**: DiskLED 3 向け新規
- **サイズ**: コンパクト 285×16 ／ フル 531×16（左ダブルクリックで切替）
- **特徴**: 横一列の情報バー。同梱スキンの中で最も横長。フルは全項目を横向きLEDバーで表示、コンパクトは情報を絞り活動LEDを併用
- **メーター**: コンパクト＝CPU使用率バー、ディスク読み書き・ネット送受信の活動LED、Ping、再生音量L/Rバー。フル＝CPU/メモリ/SWAP使用率バー、ディスク読み書き・ネット送受信の速度バー、Ping、再生音量L/Rバー

## Vintage

<img src="images/skins/vintage-compact.png" alt="Vintage（コンパクト）" width="232" height="32"><br>
<img src="images/skins/vintage-full.png" alt="Vintage（フル）" width="416" height="32">

- **由来**: DiskLED 3 向け新規
- **サイズ**: コンパクト 232×32 ／ フル 416×32（左ダブルクリックで切替）
- **特徴**: アナログVUメーター風。文字盤・目盛り・針を1コマずつ焼き込んだ64コマ描画で、針の動きが滑らか
- **メーター**: コンパクト＝CPU/メモリ使用率、ディスクI/O・ネットI/Oの統合活動メーター（読み書き/送受信の大きい方）、再生音量（モノラル）。フル＝CPU/メモリ/SWAP使用率、ディスク読み書き・ネット送受信を個別表示、再生音量（ステレオL/R）
