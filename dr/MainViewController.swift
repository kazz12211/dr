//
//  ViewController.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import UIKit
import CoreLocation
import CoreAudio
import CoreMotion
import AVFoundation
import MediaPlayer
import Photos

class MainViewController: UIViewController {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var recordButton: UIButton!
    @IBOutlet weak var configButton: UIButton!
    @IBOutlet weak var playlistButton: UIButton!
    @IBOutlet weak var freeStorageLabel: UILabel!
    @IBOutlet weak var batteryStateLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var speedLabel: UILabel!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var audioStateImage: UIButton!
    @IBOutlet weak var frameRateLabel: UILabel!
    @IBOutlet weak var videoQualityLabel: UILabel!
    
    var storageMonitoringTimer: Timer!
    var timeTimer: Timer!
    var timestampFormatter: DateFormatter = DateFormatter()
    var locationManager: CLLocationManager!
    var motionManager: CMMotionManager!
    var initialVolume: Float = 0.0
    var volumeView: MPVolumeView!
    var recorder: DriveRecorder!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // バッテリー残量の監視を開始する
        startBatteryMonitoring()
        // 設定変更の監視を開始する
        startConfigurationMonitoring()
        // ディスク空容量の監視を開始する
        startFreeStorageMonitoring()
        // 時刻表示を更新するタイマーを開始する
        startTimer()
        // GPSの受信を開始する
        startGPS()
        // 加速度センサーの監視を開始する
        startMotion()
        
        recorder = DriveRecorder()
        recorder.setup(inView: previewView)
        previewView.bringSubview(toFront: headerView)
        previewView.bringSubview(toFront: footerView)
        previewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(doFocus(_:))))

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ボリュームボタンの監視を開始する
        startListeningVolumeButton()
        // バッテリー残量の表示
        displayBatteryLevel()
        
        if recorder.authorized {
            recorder.startRunning()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        recorder.doFocus { (error) in }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // ボリュームボタンの監視を終了する
        stopListeningVolumeButton()
        
        if recorder.authorized {
            recorder.stopRunning()
        }
    }

    @IBAction func recordButtonTapped(_ sender: Any) {
        if recorder.recordingInProgress {
            recorder.stopRecording { updateState() }
        } else {
            recorder.startRecording { updateState() }
        }
    }
    
    @IBAction func doFocus(_ gestureRecognizer: UITapGestureRecognizer) {
        if recorder.authorized {
            recorder.doFocus { (error) in }
        }
    }
    
    private func updateState() {
        configButton.isEnabled = !recorder.recordingInProgress
        playlistButton.isEnabled = !recorder.recordingInProgress
        freeStorageLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        batteryStateLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        timeLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        speedLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        locationLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        frameRateLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        videoQualityLabel.textColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        audioStateImage.tintColor = recorder.recordingInProgress ? UIColor.orange : UIColor.white
        
        if recorder.recordingInProgress {
            recordButton.setImage(UIImage(named: "icon_stop"), for: .normal)
        } else {
            recordButton.setImage(UIImage(named: "icon_record"), for: .normal)
        }
    }
    
    
    // 出力音量の変化とカメラ露出を監視する
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            let newVolume = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
            // 出力音量が上がったか下がったかによって処理を分岐する
            if initialVolume > newVolume {
                volumeDown()
                initialVolume = newVolume
                if initialVolume < 0.1 {
                    initialVolume = 0.1
                }
            } else if initialVolume < newVolume {
                volumeUp()
                initialVolume = newVolume
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
}

// ボリュームボタン関連
// Bluetoothリモートシャッター（ダイソーで売られているような安価なものを使用可能）のシャッターボタン押し下げはiPhoneから見るとボリュームアップボタンの押し下げに見える
extension MainViewController {
    
    // ボリュームボタン押し下げの監視を開始
    func startListeningVolumeButton() {
        // Volumeビューを画面の外側に追い出して見えないようにする
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

    // ボリュームボタンの押し下げの監視を終了
    func stopListeningVolumeButton() {
        // 出力音量の監視を終了
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        // ボリュームビューを破棄
        volumeView.removeFromSuperview()
        volumeView = nil
    }
    
    
    // ボリュームビューの音量調整スライダーを操作することで音量を設定する
    private func setVolume(_ volume: Float) {
        (volumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(initialVolume, animated: false)
    }
    
    // ドライブレコーダーが録画中なら静止画撮影、そうでなければドライブレコーダーの録画を開始
    private func volumeUp() {
        if !recorder.recordingInProgress {
            recorder.startRecording { updateState() }
        } else {
            recorder.takePhoto()
        }
   }
    
    // ドライブレコーダーの停止
    private func volumeDown() {
        if recorder.recordingInProgress {
            recorder.stopRecording { updateState() }
        }
    }
    
}

// GPS関連
extension MainViewController {
    
    // CLLocationManagerの更新通知を開始
    private func startGPS() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        let status = CLLocationManager.authorizationStatus()
        if status == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
        }
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }
    
    // CLLocationManagerの更新通知を終了
    private func stopGPS() {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
}

extension MainViewController: CLLocationManagerDelegate {
    
    // CLLocationManagerによって更新された速度、緯度、経度、標高を記録
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            var speed = location.speed
            if speed < 0 {
                speed = 0
            }
            speed *= 3.6
            DriveInfo.singleton.speed = speed
            DriveInfo.singleton.altitude = location.altitude
            DriveInfo.singleton.latitude = location.coordinate.latitude
            DriveInfo.singleton.longitude = location.coordinate.longitude
            
            speedLabel.text = "".appendingFormat("%.fkm/h", DriveInfo.singleton.speed)
            locationLabel.text = "".appendingFormat("%.4f  %.4f  %.0fm", DriveInfo.singleton.latitude, DriveInfo.singleton.longitude, DriveInfo.singleton.altitude)
            
            if speed >= Config.default.autoStartSpeed && Config.default.autoStartEnabled && !recorder.recordingInProgress {
                recorder.startRecording {
                    updateState()
                }
            }
        }
    }
}

// Gセンサー関連
extension MainViewController {
    
    // 加速度センサーの初期化と更新通知の開始
    private func startMotion() {
        motionManager = CMMotionManager()
        if motionManager.isAccelerometerAvailable {
            motionManager.accelerometerUpdateInterval = 1 / 60
            motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: {(accelerationData, error) in
                if let e = error {
                    print(e.localizedDescription)
                }
                guard let data = accelerationData else {
                    return
                }
                // 衝撃を受けたら録画開始
                if fabs(data.acceleration.y) > Config.default.gsensorSensibility || fabs(data.acceleration.z) > Config.default.gsensorSensibility {
                    if !self.recorder.recordingInProgress {
                        self.recorder.startRecording {
                            self.updateState()
                        }
                    }
                }
            });
        }
    }
}

// バッテリー状態
extension MainViewController {
    
    // バッテリー状態の監視を開始
    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.batteryLevelChanged(notification:)), name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.batteryStateChanged(notification:)), name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
    }
    
    // バッテリー状態の監視を停止
    private func stopBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
    }
    
    // バッテリー残量が変化したら呼び出されるメソッド
    @objc private func batteryLevelChanged(notification: Notification) {
        displayBatteryLevel()
    }
    
    // バッテリー残量の画面表示
    private func displayBatteryLevel() {
        batteryStateLabel.text = "".appendingFormat("%.0f%%", UIDevice.current.batteryLevel * 100)
    }
    
    // バッテリーの充電状態が変化したら呼び出されるメソッド
    @objc private func batteryStateChanged(notification: Notification) {
        // 給電が停止したら録画を停止する
        if recorder.recordingInProgress && UIDevice.current.batteryState == .unplugged && Config.default.autoStopEnabled{
            recorder.stopRecording {
                updateState()
            }
        }
    }
}

// 設定
extension MainViewController {
    
    // 設定変更の監視を開始
    private func startConfigurationMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationLoaded(notification:)), name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationSaved(notification:)), name: Config.ConfigurationSaved, object: nil)
        Config.default.load()
    }
    
    // 設定変更の監視を終了
    private func stopConfigurationMonitoring() {
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationSaved, object: nil)
    }
    
    // 設定が読み込まれた時に呼び出されるメソッド
    @objc private func configurationLoaded(notification: Notification) {
        updateDisplay()
    }
    
    // 設定が保存された時に呼び出されるメソッド
    @objc private func configurationSaved(notification: Notification) {
        if recorder.authorized {
            recorder.stopRunning()
        }
        recorder.configurationChanged()
        updateDisplay()
        if recorder.authorized {
            recorder.startRunning()
        }
    }
    // 設定内容を画面に反映する
    private func updateDisplay() {
        if Config.default.recordAudio {
            audioStateImage.setImage(UIImage(named: "icon_audio_on"), for: .normal)
        } else {
            audioStateImage.setImage(UIImage(named: "icon_audio_off"), for: .normal)
        }
        
        if Config.default.videoQuality == Constants.VideoQualityHigh {
            videoQualityLabel.text = "1920x1080"
        } else if Config.default.videoQuality == Constants.VideoQualityMedium {
            videoQualityLabel.text = "1280x720"
        } else {
            videoQualityLabel.text = "640x480"
        }
        
        frameRateLabel.text = "\(Config.default.frameRate)fps"
    }
}

// 空き容量
extension MainViewController {
    
    // ストレージの空き容量表示を定期的に更新するためのタイマーの開始
    private func startFreeStorageMonitoring() {
        storageMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true, block: { (timer) in
            let freeStorageSize = self.calculateFreeStorage()
            self.freeStorageLabel.text = "".appendingFormat("%.0fGB", freeStorageSize.doubleValue)
            if freeStorageSize.doubleValue <= 1.0 {
                if self.recorder.recordingInProgress {
                    self.recorder.stopRecording { self.updateState() }
                }
            }
        })
        storageMonitoringTimer.fire()
    }
    
    // ストレージの空き容量表示を定期的に更新するためのタイマーの停止
    private func stopFreeStorageMonitoring() {
        storageMonitoringTimer.invalidate()
    }
    // 空容量を計算してGBの単位で返す
    private func calculateFreeStorage() -> NSNumber {
        let documentDirPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        if let sysAttributes = try? FileManager.default.attributesOfFileSystem(forPath: documentDirPath.last!) {
            if let freeStorageSize = sysAttributes[FileAttributeKey.systemFreeSize] as? NSNumber {
                let freeStorageGigaBytes = freeStorageSize.doubleValue / Double(1024 * 1024 * 1024)
                return NSNumber(value: round(freeStorageGigaBytes))
            }
        }
        return NSNumber(value:0.0)
    }
}

// 画面に表示する時刻を更新するためのタイマー
extension MainViewController {
    
    private func startTimer() {
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timer) in
            self.timeLabel.text = Formatters.default.timestampFormatter.string(from: Date())
        })
    }
    
    private func stopTimer() {
        timeTimer.invalidate()
    }
    
}
