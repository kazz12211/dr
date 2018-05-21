//
//  DriveRecorder.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/21.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import AVFoundation
import Photos

class DriveRecorder : NSObject {
    
    var recordingInProgress: Bool = false
    var captureSession: AVCaptureSession!
    var videoDevice: AVCaptureDevice!
    var audioDevice: AVCaptureDevice!
    var videoInput: AVCaptureDeviceInput!
    var audioInput: AVCaptureDeviceInput!
    var videoWriter: VideoWriter!
    var authorized: Bool = false
    var adjustingExposure: Bool = false
    var quality: AVCaptureSession.Preset?
    var fps: Int32?
    
    override init() {
        super.init()
        
        captureSession = AVCaptureSession()
        
        self.checkCameraAuthorization { (authorized) in
            self.checkPhotoLibraryAuthorization({ (authorized) in
                self.authorized = authorized
            })
        }
    }
    
    func setup(inView previewView: UIView) {
        setupRecorder()
        setupPreviewLayer(inView: previewView)
    }
    
    func startRunning() {
        captureSession.startRunning()
    }
    
    func stopRunning() {
        captureSession.stopRunning()
    }
    
    func configurationChanged() {
        captureSession.beginConfiguration()
        removeCamera()
        removeMicrophone()
        captureSession.commitConfiguration()
        setupRecorder()
    }
    
    func startRecording(_ completionHandler: () -> Void) {
        doFocus { (error) in
            if error != nil {
                print(error)
            }
        }
        videoWriter = VideoWriter(session: captureSession)
        recordingInProgress = videoWriter.start()
        completionHandler()
    }
    
    func stopRecording(_ completionHandler: () -> Void) {
        videoWriter.stop()
        recordingInProgress = false
        videoWriter = nil
        completionHandler()
    }
    
    func takePhoto() {
        videoWriter.takeStillImage()
    }
    
    func doFocus(_ withError: @escaping ((_ error: Error?) -> Void)) {
        if videoInput != nil {
            let device = videoInput.device
            do {
                try device.lockForConfiguration()
                focus(.autoFocus)
                device.unlockForConfiguration()
            } catch {
                withError(error)
            }
        }
    }
}

// カメラ・マイク設定

extension DriveRecorder {
    
    private func setupWriter() {
        videoWriter = VideoWriter(session: captureSession)
    }
    
    private func setupPreviewLayer(inView previewView: UIView) {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = previewView.bounds
        previewView.layer.addSublayer(previewLayer)
        
        if let previewLayerConnection = previewLayer.connection {
            previewLayerConnection.videoOrientation = .landscapeRight
        }
    }
    
    private func setupRecorder() {
        captureSession.beginConfiguration()
        
        addCamera()
        addMicrophone()
        
        captureSession.commitConfiguration()
    }
    
    private func addCamera() {
        let discoverSession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
        let devices = discoverSession.devices
        videoDevice = devices.first
        
        if videoDevice != nil {
            // 露出をロックしたい場合
            //videoDevice.addObserver(self, forKeyPath: "adjustingExposure", options: .new, context: nil)
            configureCamera(quality: Config.default.videoQuality, fps: Config.default.frameRate) { (error) in
                if error == nil {
                    do {
                        self.videoInput = try AVCaptureDeviceInput(device: self.videoDevice)
                        if self.captureSession.canAddInput(self.videoInput) {
                            self.captureSession.addInput(self.videoInput)
                        }
                    } catch {
                        print("cannot setup video input device: \(error)")
                    }
                }
            }
        }
        
    }
    
    private func removeCamera() {
        if videoInput != nil {
            captureSession.removeInput(videoInput)
            videoInput = nil
            videoDevice = nil
        }
    }
    
    private func addMicrophone() {
        audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified)
        do {
            audioInput = try AVCaptureDeviceInput(device: audioDevice)
            if captureSession.canAddInput(audioInput) {
                captureSession.addInput(audioInput)
            }
        } catch {
            print("cannot setup audio input device: \(error)")
        }
    }
    
    private func removeMicrophone() {
        if audioInput != nil {
            captureSession.removeInput(audioInput)
            audioInput = nil
            audioDevice = nil
        }
    }
    
    private func configureCamera(quality: AVCaptureSession.Preset, fps: Int32, _ completionHandler: @escaping ((_ error: Error?) -> Void)) {
        do {
            try videoDevice.lockForConfiguration()
            
            self.fps = fps
            self.quality = quality

            captureSession.sessionPreset = self.quality!

            let frameRateRanges =  videoDevice.activeFormat.videoSupportedFrameRateRanges
            for frameRate in frameRateRanges {
                if Config.default.frameRate < Int32(frameRate.minFrameRate) || Config.default.frameRate > Int32(frameRate.maxFrameRate) {
                    self.fps = Constants.DefaultFrameRate
                    Config.default.frameRate = self.fps!
                    Config.default.silentSave()
                }
            }
            videoDevice.activeVideoMinFrameDuration = CMTime(value: 1, timescale: self.fps!);
            
            lowLightBoost(true)
            
            videoHDR(true)
            
            focus(.autoFocus)
            
            exposure(.continuousAutoExposure)

            videoDevice.unlockForConfiguration()
            
            
            completionHandler(nil)
        } catch {
            completionHandler(error)
        }
    }
    
    // 暗いところでの明るさブースト設定
    private func lowLightBoost(_ enabled: Bool) {
        if self.videoDevice.isLowLightBoostEnabled {
            self.videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = enabled
        }
    }
    
    // Video HDR設定
    private func videoHDR(_ enabled: Bool) {
        if self.videoDevice.isVideoHDREnabled {
            self.videoDevice.isVideoHDREnabled = enabled
        }
    }

    // フォーカス設定
    private func focus(_ mode: AVCaptureDevice.FocusMode) {
        if self.videoDevice.isFocusModeSupported(.autoFocus) && self.videoDevice.isFocusPointOfInterestSupported {
            // 画面の中心にオートフォーカス
            self.videoDevice.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.videoDevice.focusMode = mode
        }
    }

    // 露出設定
    private func exposure(_ mode: AVCaptureDevice.ExposureMode) {
        if self.videoDevice.isExposureModeSupported(.continuousAutoExposure) && self.videoDevice.isExposurePointOfInterestSupported {
            // 露出をロックしたい時
            //self.adjustingExposure = true
            // 画面の中心に露出を合わせる
            self.videoDevice.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
            self.videoDevice.exposureMode = mode
        }
    }
}

// カメラの使用許可とフォトアルバムの使用許可
extension DriveRecorder {
    
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
