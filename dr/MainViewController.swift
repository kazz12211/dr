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
 
    var initialVolume = 0.0
    
    var authorized: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        startBatteryMonitoring()
        startConfigurationMonitoring()
        startFreeStorageMonitoring()
        startTimer()
        startGPS()
        startMotion()
        
        checkCameraAuthorization { (authorized) in
            if authorized {
                self.setupCaptureSession()
                self.setupCaptureDevice()
                self.setupPreviewLayer()
                self.checkPhotoLibraryAuthorization({ (authorized) in
                    if authorized {
                        self.setupVideoWriter()
                        self.updateState()
                        self.authorized = authorized
                    }
                })
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        listenVolumeButton()
        displayBatteryLevel()
        if authorized {
            configureCaptureDevice()
            if !captureSession.isRunning {
                startCaptureSession()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        if authorized {
            if captureSession.isRunning {
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
}

// ボリュームボタン関連

extension MainViewController {
    
    
    func listenVolumeButton() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            let vol = audioSession.outputVolume
            initialVolume = Double(vol.description)!
            if initialVolume > 0.9 {
                initialVolume = 0.9
            } else if initialVolume < 0.1 {
                initialVolume = 0.1
            }
            audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        } catch {
            print("Could not observer outputVolume ", error)
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            let volume = (change?[NSKeyValueChangeKey.newKey] as! NSNumber).floatValue
            let newVolume = Double(volume)
            if initialVolume > newVolume {
                volumeDown()
                initialVolume = newVolume
            } else if initialVolume < newVolume {
                volumeUp()
                initialVolume = newVolume
            }
        }
    }
    
    private func volumeUp() {
        if !recordingInProgress {
            startRecording()
        } else {
            takePhoto()
        }
    }
    
    private func volumeDown() {
        if recordingInProgress {
            stopRecording()
        }
    }
    
    private func takePhoto() {
        print("Taking photo")
        videoWriter.takeStillImage()
    }

}

// ビデオ関連

extension MainViewController {
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = Config.default.videoQuality
    }
    
    private func setupCaptureDevice() {
        addVideoDevice()
        
        if Config.default.recordAudio {
            addAudioDevice()
        }
    }
    
    private func configureCaptureDevice() {
        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Config.default.frameRate)
            // 暗いところでの明るさブースト
            if videoDevice.isLowLightBoostEnabled {
                videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            // フォーカス設定
            // 画面の中心にオートフォーカス
            if videoDevice.isFocusModeSupported(.locked) && videoDevice.isFocusPointOfInterestSupported {
                videoDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
                videoDevice.focusMode = .autoFocus
            }
            // Video HDRの設定
            if videoDevice.isVideoHDREnabled {
                videoDevice.isVideoHDREnabled = true
            }
            videoDevice.unlockForConfiguration()
        } catch {
            
        }
    }
    
    private func resetCaptureDevice() {
        if captureSession.isRunning {
            stopCaptureSession()
        }
        removeVideoDevice()
        removeAudioDevice()
        setupCaptureDevice()
    }
    
    private func addVideoDevice() {
        let discoverSession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        let devices = discoverSession.devices
        
        videoDevice = devices.first
        
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
    
    private func removeVideoDevice() {
        if videoInput != nil {
            captureSession.removeInput(videoInput)
            videoInput = nil
            videoDevice = nil
        }
    }
    
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
    
    private func removeAudioDevice() {
        if audioInput != nil {
            captureSession.removeInput(audioInput)
            audioInput = nil
            audioDevice = nil
        }
    }

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
    }
    
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
    
    private func stopGPS() {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
}

extension MainViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            var speed = location.speed
            if speed < 0 {
                speed = 0
            }
            DriveInfo.singleton.speed = speed * 3.6
            
            DriveInfo.singleton.altitude = location.altitude
            DriveInfo.singleton.latitude = location.coordinate.latitude
            DriveInfo.singleton.longitude = location.coordinate.longitude
            
            speedLabel.text = "".appendingFormat("%.fkm/h", DriveInfo.singleton.speed)
            locationLabel.text = "".appendingFormat("%.4f  %.4f  %.0fm", DriveInfo.singleton.latitude, DriveInfo.singleton.longitude, DriveInfo.singleton.altitude)
            
            if speed > Config.default.autoStartSpeed && Config.default.autoStartEnabled && !recordingInProgress {
                startRecording()
            }
        }
    }
}

// Gセンサー関連
extension MainViewController {
    
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
    
    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.batteryLevelChanged(notification:)), name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.batteryStateChanged(notification:)), name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
    }
    
    private func stopBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = false
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIDeviceBatteryLevelDidChange, object: nil)
        NotificationCenter.default.removeObserver(self, name: Notification.Name.UIDeviceBatteryStateDidChange, object: nil)
    }
    
    @objc private func batteryLevelChanged(notification: Notification) {
        displayBatteryLevel()
    }
    
    private func displayBatteryLevel() {
        batteryStateLabel.text = "".appendingFormat("%.0f%%", UIDevice.current.batteryLevel * 100)
    }
    
    @objc private func batteryStateChanged(notification: Notification) {
        if recordingInProgress && UIDevice.current.batteryState == .unplugged && Config.default.autoStopEnabled{
            stopRecording()
        }
    }
}

// 設定
extension MainViewController {
    
    private func startConfigurationMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationLoaded(notification:)), name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationSaved(notification:)), name: Config.ConfigurationSaved, object: nil)
        Config.default.load()
    }
    
    private func stopConfigurationMonitoring() {
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationSaved, object: nil)
    }
    
    @objc private func configurationLoaded(notification: Notification) {
        updateDisplay()
    }
    
    @objc private func configurationSaved(notification: Notification) {
        resetCaptureDevice()
        videoWriter.reset()
        updateDisplay()
        if !captureSession.isRunning {
            startCaptureSession()
        }
    }
    
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
    
    
    private func startFreeStorageMonitoring() {
        storageMonitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true, block: { (timer) in
            let freeStorageSize = self.calculateFreeStorage()
            self.freeStorageLabel.text = "".appendingFormat("%.0fGB", freeStorageSize.doubleValue)
        })
        storageMonitoringTimer.fire()
    }
    
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
