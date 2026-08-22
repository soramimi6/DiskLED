# クレジット・謝辞

[English](EN/CREDITS.md)

## 本ソフトウェア（DiskLED 3）

- 再構築・実装: SoRaMiMi（旧名 短波）
- 公式サイト: [https://mg6.jp/](https://mg6.jp/)
- 公開用連絡先: [sw@mg6.jp](mailto:sw@mg6.jp)
- 開発環境: Delphi（VCL）

## 表示アセット（旧スキン由来）

第1版の見た目は、旧 DiskLED に同梱・流通していたスキン画像を、表示モード用アセットとして再配置したものです。


| 表示モード    | 旧称・由来                         |
| -------- | ----------------------------- |
| Original | System Analog Meter II（sam2）系 |
| Crystal  | Mac OS X 風スキン（MacX）系          |
| Metalic  | xsrv SkinS 系                  |


公開パッケージには、可能な範囲で原作者表記を README / 本ファイルに明記します。連絡先や正しいクレジット表記が判明し次第、追記・修正します。

## 旧 DiskLED 2.x

Windows XP 時代の DiskLED およびヘルプ・スキン文化に感謝します。3.x は互換実装ではなく、同じ「常駐ランプ／メーター」という目的のための再設計です。

## 利用ライブラリについて

3.x は主に Windows API（パフォーマンス計測・ICMP・IP Helper 等）を直接利用する構成です。依存コンポーネントが増えた場合は本ファイルに追記します。