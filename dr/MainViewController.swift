//
//  ViewController.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import CoreLocation
import CoreAudio
import CoreMotion
import AVFoundation

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
    
    var driveInfo: DriveInfo = DriveInfo()
    var config: Config = Config()
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
    var videoOutput: AVCaptureVideoDataOutput!
    var assetWriter: AVAssetWriter!
    var assetInput: AVAssetWriterInput!
    var pixelBuffer: AVAssetWriterInputPixelBufferAdaptor!
    var frameNumber: Int64 = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        startBatteryMonitoring()
        startConfigurationMonitoring()
        startFreeStorageMonitoring()
        startTimer()
        startGPS()
        startMotion()
        
        setupCaptureSession()
        setupPreviewLayer()
        setupVideoOutput()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.stopRunning()
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
        recordingInProgress = true
        recordButton.setImage(UIImage(named: "icon_pause"), for: .normal)
        let documentPath = NSHomeDirectory() + "/Documents/"
        let date = Date()
        let filePath = documentPath + date.filenameFromDate() + ".mp4"
        let fileURL = URL(fileURLWithPath: filePath)
        startRecordingVideo(fileURL)
    }
    
    func stopRecording() {
        recordingInProgress = false
        recordButton.setImage(UIImage(named: "icon_record"), for: .normal)
        stopRecordingVideo()
    }
}

// ビデオ関連

extension MainViewController {
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = config.videoQuality
        
        setupCaptureDevice()
    }
    
    private func setupCaptureDevice() {
        let discoverSession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        let devices = discoverSession.devices
        
        videoDevice = devices.first
        videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }
        } catch {
            print("cannot setup video input device", error)
        }
        
        if config.recordAudio {
            addAudioDevice()
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
    
    private func setupVideoOutput() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)] as [String : Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
    }
    
    private func startRecordingVideo(_ url: URL) {
        let width = config.videoQuality == Constants.VideoQualityHigh ? 1920 : config.videoQuality == Constants.VideoQualityMedium ? 1280 : 640
        let height = config.videoQuality == Constants.VideoQualityHigh ? 1080 : config.videoQuality == Constants.VideoQualityMedium ? 720 : 480
        let inputSettings = [AVVideoWidthKey: width, AVVideoHeightKey: height, AVVideoCodecKey: AVVideoCodecType.h264] as [String:Any]
        
        assetInput = AVAssetWriterInput(mediaType: .video, outputSettings: inputSettings)
        pixelBuffer = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])

        do {
            try assetWriter = AVAssetWriter(outputURL: url, fileType: .mp4)
            assetWriter.add(assetInput)
            assetInput.expectsMediaDataInRealTime = true
        } catch {
            
        }
        
        frameNumber = 0
        
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: kCMTimeZero)
    }
    
    private func stopRecordingVideo() {
        if assetWriter != nil {
            assetWriter.finishWriting {
                self.pixelBuffer = nil
            }
        }
    }
}

extension MainViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            if assetInput.isReadyForMoreMediaData {
                print("recording: \(frameNumber)")
                pixelBuffer.append(imageBuffer, withPresentationTime: CMTimeMake(frameNumber, 25))
                frameNumber += 1
            }
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
            driveInfo.speed = speed * 3.6
            
            driveInfo.altitude = location.altitude
            driveInfo.latitude = location.coordinate.latitude
            driveInfo.longitude = location.coordinate.longitude
            
            speedLabel.text = "".appendingFormat("%.fkph", driveInfo.speed)
            locationLabel.text = "".appendingFormat("%.4f  %.4f  %.0fm", driveInfo.latitude, driveInfo.longitude,driveInfo.altitude)
            
            if speed > config.autoStartSpeed && config.autoStartEnabled && !recordingInProgress {
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
                if fabs(data.acceleration.y) > self.config.gsensorSensibility || fabs(data.acceleration.z) > self.config.gsensorSensibility {
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
        batteryStateLabel.text = "".appendingFormat("%.0f%", UIDevice.current.batteryLevel)
    }
    
    @objc private func batteryStateChanged(notification: Notification) {
        if recordingInProgress && UIDevice.current.batteryState == .unplugged && config.autoStopEnabled{
            stopRecording()
        }
    }
}

// 設定
extension MainViewController {
    
    private func startConfigurationMonitoring() {
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationLoaded(notification:)), name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MainViewController.configurationSaved(notification:)), name: Config.ConfigurationSaved, object: nil)
        config.load()
    }
    
    private func stopConfigurationMonitoring() {
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationLoaded, object: nil)
        NotificationCenter.default.removeObserver(self, name: Config.ConfigurationSaved, object: nil)
    }
    
    @objc private func configurationLoaded(notification: Notification) {
        
    }
    
    @objc private func configurationSaved(notification: Notification) {
        
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
        timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        timeTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { (timer) in
            self.timeLabel.text = self.timestampFormatter.string(from: Date())
        })
    }
    
    private func stopTimer() {
        timeTimer.invalidate()
    }
    
}
