## アプリの中でボリュームボタンを監視する方法 (iOS & Swift)

iOSデバイスのカメラアプリはボリューム（＋）ボタンを押し下げるとシャッターを切ります。ボリュームボタンの押し下げを検知すれば、Bluetoothリモートシャッターやヘッドセット（iPhoneに付属するイヤホンなど）を使って、自分のアプリをコントロールすることができます。

#### ボリュームボタン押し下げの監視を開始

~~~
func startListeningVolumeButton() {
    // MPVolumeViewを画面の外側に追い出して見えないようにする
    let frame = CGRect(x: -100, y: -100, width: 100, height: 100)
    volumeView = MPVolumeView(frame: frame)
    volumeView.sizeToFit()
    view.addSubview(volumeView)

    let audioSession = AVAudioSession.sharedInstance()
    do {
        try audioSession.setActive(true)
        // AVAudioSessionの出力音量を取得して、最大音量と無音に振り切れないように初期音量を設定する
        let vol = audioSession.outputVolume
        initialVolume = Float(vol.description)!
        if initialVolume > 0.9 {
            initialVolume = 0.9
        } else if initialVolume < 0.1 {
            initialVolume = 0.1
        }
        setVolume(initialVolume)
        // 出力音量の監視を開始
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
    } catch {
        print("Could not observer outputVolume ", error)
    }
}
~~~

#### ボリュームボタンの押し下げの監視を終了

~~~
func stopListeningVolumeButton() {
    // 出力音量の監視を終了
    AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
    // ボリュームビューを破棄
    volumeView.removeFromSuperview()
    volumeView = nil
}
~~~

### ボリュームビューの音量調整スライダーを操作することで音量を設定する

~~~
func setVolume(_ volume: Float) {
    (volumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(initialVolume, animated: false)
}
~~~

#### 出力音量の変化とカメラ露出を監視する

ビューコントローラーのobserverValue()をオーバライドして出力音量の変化に対してアクションを実行します

~~~
...
import MediaPlayer

class MyViewController: ViewController {
  ...
  var initialVolume: Float = 0.0
  var volumeView: MPVolumeView!
  ...
  ...

  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
      if keyPath == "outputVolume" {
          let newVolume = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
          // 出力音量が上がったか下がったかによって処理を分岐する
          if initialVolume > newVolume {
              // ボリュームが下がった時の処理をここに記述
              initialVolume = newVolume
              // ボリュームが０になってしまうと以降のボリューム（ー）操作を検知できないので、０より大きい適当に小さい値に設定する
              if initialVolume < 0.1 {
                  initialVolume = 0.1
              }
          } else if initialVolume < newVolume {
              // ボリュームが上がった時の処理をここに記述
              initialVolume = newVolume
              // ボリュームが１になってしまうと以降のボリューム（＋）操作を検知できないので、１より小さい適当に大きい値に設定する
              if initialVolume > 0.9 {
                  initialVolume = 0.9
              }
          }
          // 一旦出力音量の監視をやめて出力音量を設定してから出力音量の監視を再開する
          AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
          setVolume(initialVolume)
          AVAudioSession.sharedInstance().addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
      }
  }

  ...
}
~~~
