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
    var recordingInProgress: Bool = false
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    var captureSession: AVCaptureSession!
    var videoDevice: AVCaptureDevice!
    var audioDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    
    var videoWriter: VideoWriter!
 
    var initialVolume: Float = 0.0
    
    var authorized: Bool = false
    
    var volumeView: MPVolumeView!
    
    // 露出をロックしたい時
    //var adjustingExposure: Bool = false
    
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
        
        // カメラの使用確認
        checkCameraAuthorization { (authorized) in
            if authorized {
                // キャプチャーセッションの設定
                self.setupCaptureSession()
                // キャプチャー入力デバイスの設定
                // バックカメラとビルトインマイクを使用する
                self.setupCaptureDevice()
                // キャプチャー映像を表示するビューを設定する
                self.setupPreviewLayer()
                // フォトアルバムへのアクセス権を確認
                self.checkPhotoLibraryAuthorization({ (authorized) in
                    if authorized {
                        // ビデオの書き出し設定
                        self.setupVideoWriter()
                        // 画面の更新
                        self.updateState()
                        self.authorized = authorized
                    }
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // ボリュームボタンの監視を開始する
        startListeningVolumeButton()
        // バッテリー残量の表示
        displayBatteryLevel()
        if authorized {
            // キャプチャー入力デバイスの再設定
            configureCaptureDevice()
            if !captureSession.isRunning {
                // キプチャーセッションの開始
                startCaptureSession()
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if authorized {
            // キャプチャー入力デバイスの再設定
            configureCaptureDevice()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // ボリュームボタンの監視を終了する
        stopListeningVolumeButton()
        if authorized {
            if captureSession.isRunning {
                // キャプチャーセッションの停止
                stopCaptureSession()
            }
        }
    }

    @IBAction func recordButtonTapped(_ sender: Any) {
        if recordingInProgress {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    @IBAction func doFocus(_ gestureRecognizer: UITapGestureRecognizer) {
        if videoInput != nil {
            let device = videoInput.device
            do {
                try device.lockForConfiguration()
                focus()
                device.unlockForConfiguration()
            } catch {}
        }
    }
    
    func startRecording() {
        if authorized {
            recordingInProgress = videoWriter.start()
        }
        updateState()
    }
    
    func stopRecording() {
        if authorized {
            videoWriter.stop()
        }
        recordingInProgress = false
        updateState()
    }
    
    private func updateState() {
        configButton.isEnabled = !recordingInProgress
        playlistButton.isEnabled = !recordingInProgress
        freeStorageLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        batteryStateLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        timeLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        speedLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        locationLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        frameRateLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        videoQualityLabel.textColor = recordingInProgress ? UIColor.orange : UIColor.white
        audioStateImage.tintColor = recordingInProgress ? UIColor.orange : UIColor.white
        
        if recordingInProgress {
            recordButton.setImage(UIImage(named: "icon_stop"), for: .normal)
        } else {
            recordButton.setImage(UIImage(named: "icon_record"), for: .normal)
        }
        
        timeLabel.isHidden = !recordingInProgress
        speedLabel.isHidden = !recordingInProgress
        locationLabel.isHidden = !recordingInProgress
    }
    
    // from Apple developer site
    func checkCameraAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            //The user has previously granted access to the camera.
            completionHandler(true)
            
        case .notDetermined:
            // The user has not yet been presented with the option to grant video access so request access.
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { success in
                completionHandler(success)
            })
            
        case .denied:
            // The user has previously denied access.
            completionHandler(false)
            
        case .restricted:
            // The user doesn't have the authority to request access e.g. parental restriction.
            completionHandler(false)
        }
    }
    
    // from Apple developer site
    func checkPhotoLibraryAuthorization(_ completionHandler: @escaping ((_ authorized: Bool) -> Void)) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            // The user has previously granted access to the photo library.
            completionHandler(true)
            
        case .notDetermined:
            // The user has not yet been presented with the option to grant photo library access so request access.
            PHPhotoLibrary.requestAuthorization({ status in
                completionHandler((status == .authorized))
            })
            
        case .denied:
            // The user has previously denied access.
            completionHandler(false)
            
        case .restricted:
            // The user doesn't have the authority to request access e.g. parental restriction.
            completionHandler(false)
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
        // 露出をロックしたい場合
        /*else if keyPath == "adjustingExposure" {
            if !adjustingExposure {
                return
            }
            
            if (change?[NSKeyValueChangeKey.newKey] as! Bool) == false {
                adjustingExposure = false
                do {
                    try videoDevice.lockForConfiguration()
                    videoDevice.exposureMode = .locked
                    videoDevice.unlockForConfiguration()
                } catch {
                    
                }
            }
        }*/
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
        if !recordingInProgress {
            startRecording()
        } else {
            takePhoto()
        }
    }
    
    // ドライブレコーダーの停止
    private func volumeDown() {
        if recordingInProgress {
            stopRecording()
        }
    }
    
    private func takePhoto() {
        videoWriter.takeStillImage()
    }
    
    
}

// ビデオ関連

extension MainViewController {
    
    // AVCaptureSessionの設定
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
    }
    
    // キャプチャーデバイスをAVCaptureSessionに追加する
    private func setupCaptureDevice() {
        captureSession.beginConfiguration()
        removeVideoDevice()
        removeAudioDevice()
        addVideoDevice()
        
        if Config.default.recordAudio {
            addAudioDevice()
        }
        captureSession.sessionPreset = Config.default.videoQuality
        captureSession.commitConfiguration()
    }
    
    // カメラの設定
    private func configureCaptureDevice() {
        do {
            try self.videoDevice.lockForConfiguration()
            let frameRateRanges =  videoDevice.activeFormat.videoSupportedFrameRateRanges
            for frameRate in frameRateRanges {
                if Config.default.frameRate < Int32(frameRate.minFrameRate) || Config.default.frameRate > Int32(frameRate.maxFrameRate) {
                    Config.default.frameRate = Constants.DefaultFrameRate
                    Config.default.silentSave()
                    updateDisplay()
                }
            }
            self.videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Config.default.frameRate)
            // 暗いところでの明るさブースト
            if self.videoDevice.isLowLightBoostEnabled {
                self.videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            // Video HDRの設定
            if self.videoDevice.isVideoHDREnabled {
                self.videoDevice.isVideoHDREnabled = true
            }
            
            // フォーカス設定
            self.focus()
            
            self.videoDevice.unlockForConfiguration()
        } catch {
            
        }
    }
    
    // フォーカス設定
    private func focus() {
        // フォーカス設定
        // 画面の中心にオートフォーカス
        if self.videoDevice.isFocusModeSupported(.autoFocus) && self.videoDevice.isFocusPointOfInterestSupported {
            self.videoDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.videoDevice.focusMode = .autoFocus
        }
        
        // 露出の設定
        // 画面の中心に露出を合わせる
        if self.videoDevice.isExposureModeSupported(.continuousAutoExposure) && self.videoDevice.isExposurePointOfInterestSupported {
            // 露出をロックしたい時
            //self.adjustingExposure = true
            self.videoDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.videoDevice.exposureMode = .continuousAutoExposure
        }
    }
    
    // キャプチャーデバイスの再構成
    private func resetCaptureDevice() {
        if captureSession.isRunning {
            stopCaptureSession()
        }
        setupCaptureDevice()
    }
    
    // ビデオ入力デバイス（バックカメラ）をAVCaptureSessionに追加する
    private func addVideoDevice() {
        let discoverSession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        let devices = discoverSession.devices
        
        videoDevice = devices.first
        
        // 露出をロックしたい場合
        //videoDevice.addObserver(self, forKeyPath: "adjustingExposure", options: .new, context: nil)
        configureCaptureDevice()
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("cannot setup video input device", error)
        }
    }
    
    // ビデオ入力デバイス（バックカメラ）をAVCaptureSessionから取り除く
    private func removeVideoDevice() {
        if videoInput != nil {
            captureSession.removeInput(videoInput)
            videoInput = nil
            videoDevice = nil
        }
    }
    
    // オーディオ入力デバイス（ビルトインマイク）をAVCaptureSessionに追加する
    // Bluetoothヘッドセットを使うと、ヘッドセットのマイクが使われる
    private func addAudioDevice() {
        audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified)
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        } catch {
            print("cannot setup audio input device", error)
        }
    }
    
    // オーディオ入力デバイス（ビルトインマイク）をAVCaptureSessionから取り除く
    private func removeAudioDevice() {
        if audioInput != nil {
            captureSession.removeInput(audioInput)
            audioInput = nil
            audioDevice = nil
        }
    }

    // AVCaptureSessionのプレビュー画面の設定
    private func setupPreviewLayer() {
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        
        if let previewLayerConnection = previewLayer.connection {
            previewLayerConnection.videoOrientation = .landscapeRight
        }
        
        previewView.bringSubview(toFront: headerView)
        previewView.bringSubview(toFront: footerView)
        previewView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(doFocus(_:))))
    }
    
    // ビデオ書き込みの準備
    private func setupVideoWriter() {
        videoWriter = VideoWriter(session: captureSession)
    }
    
    private func startCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    private func stopCaptureSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
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
            
            // 設定速度（ConfigのautoStartSpeed）に達したら録画を開始する
            if speed >= Config.default.autoStartSpeed && Config.default.autoStartEnabled && !recordingInProgress {
                startRecording()
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
                    if !self.recordingInProgress {
                        self.startRecording()
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
        if recordingInProgress && UIDevice.current.batteryState == .unplugged && Config.default.autoStopEnabled{
            stopRecording()
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
        resetCaptureDevice()
        updateDisplay()
        if !captureSession.isRunning {
            startCaptureSession()
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
                self.stopRecording()
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
