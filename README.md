# iPhone版ドライブレコーダー - dr

使用していない旧機種のiPhoneの再利用とオートバイで使用することを前提に操作が簡単な（起動さえしておけばほとんど画面操作をしなくて済む）ドライブレコーダーアプリです。

iPhone版ドライブレコーダー「ドラカメ」の第２版です。旧ドラカメはGPS速度計を兼ねたもので、Bluetoothマイコンで製作した速度警告灯と接続して使用するのを前提にしていましたが、第２版は速度警告灯との接続機能を除いて構造を簡素化しドライブレコーダー機能のみのアプリにしました。

旧「ドラカメ」のソースコードは[drivecamera](https://github.com/kazz12211/drivecamera)で公開しています。

## スクリーンショット

録画中のメイン画面

![](./screenshots/ScreenShot_Main.png)
-----
設定画面

![](./screenshots/ScreenShot_Config.png)
-----
プレイリスト画面

![](./screenshots/ScreenShot_Playlist.png)
-----
再生画面

![](./screenshots/ScreenShot_Player.png)
-----
エクスポート画面

![](./screenshots/ScreenShot_Export.png)
-----

## 主な機能

- ビデオ品質は1920x1080、1280x720、640x480から選択が可能
- ビデオのフレームレートは25fps、30fps、60fpsから選択が可能
- 音声の同時録音機能のオンオフが可能
- Gセンサー機能により衝撃を受けると録画を開始
- Gセンサーの感度は強・中・弱から選択が可能
- 給電が停止されると録画を自動停止する機能のオンオフが可能
- 指定した速度を超えたら自動的に録画を開始する機能のオンオフが可能
- 記録した動画の再生
- 記録した動画をAirDropなどを利用して他の端末に転送可能
- 時刻、速度、位置情報を動画に合成して保存
- 画面サイズは5sに合わせ、ホームボタンを向かって右にして横置きが前提
- ビデオはH264、オーディオはACCでエンコード
- ビデオファイルの形式はMP4
- 残記憶容量の表示
- バッテリー残量の表示

## 開発状況

- 音声録音が正常に動作していません
- 一定時間でビデオを分割保存する機能は未実装です
- イベント録画（衝撃を受けた際に前後のビデオを別ファイルで記録する機能）は未実装です

## 開発環境

- iOS 11.3.1
- Xcode 9.3.1
- Swift 4.1
- iOS 11.3 SDK
- iPhone 5s
- 使用フレームワーク
  - UIKit
  - CoreLocation
  - CoreMotion
  - CoreAudio
  - CoreVideo
  - AVFoundation など

## 製作に関連する読み物

ブログでギター製作、革製品や帆布製品の製作、電子工作やソフトウェア開発などのモノづくりに関連する記事を日々更新しています。

[椿工藝舎のブログ](https://tsubakicraft.wordpress.com)

## 椿工藝舎について

[椿工藝舎のホームページ](http://tsubakicraftp.jp)をご覧ください
