//
//  Config.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import Foundation
import AVFoundation

struct Constants {
    static let GSensorSensibilityKey = "GSenserSensibility"
    static let AutoStartEnabledKey = "AutoStartEnabled"
    static let AutoStopEnabledKey = "AutoStopEnabled"
    static let VideoQualityKey = "VideoQuality"
    static let RecordAudioKey = "RecordAudio"
    static let AutoStartSpeedKey = "AutoStartSpeed"
    static let VideoFrameRateKey = "FPS"
    static let GSensorStrong = 4.0
    static let GSensorMedium = 2.8
    static let GSensorWeak = 1.8
    static let DefaultAutoStartSpeed = 10.0
    static let VideoQualityHigh = AVCaptureSession.Preset.hd1920x1080
    static let VideoQualityMedium = AVCaptureSession.Preset.hd1280x720
    static let VideoQualityLow = AVCaptureSession.Preset.vga640x480
    static let VideoFrameRate25fps = Int32(25)
    static let VideoFrameRate30fps = Int32(30)
    static let VideoFrameRate60fps = Int32(60)
    static let DefaultFrameRate = VideoFrameRate30fps
}

class Config: NSObject {
    
    static let `default` = Config()
    
    var gsensorSensibility: Double = Constants.GSensorStrong
    var autoStartEnabled: Bool = false
    var autoStopEnabled: Bool = false
    var autoStartSpeed = Constants.DefaultAutoStartSpeed
    var recordAudio: Bool = false
    var videoQuality: AVCaptureSession.Preset = Constants.VideoQualityMedium
    var availableVideoQualities: [AVCaptureSession.Preset] = [Constants.VideoQualityHigh, Constants.VideoQualityMedium, Constants.VideoQualityLow]
    var availableGSensorSensibilities:[Double] = [Constants.GSensorStrong, Constants.GSensorMedium, Constants.GSensorWeak]
    var availableFrameRates: [Int32] = [Constants.VideoFrameRate60fps, Constants.VideoFrameRate30fps, Constants.VideoFrameRate25fps]
    var frameRate: Int32 = Constants.VideoFrameRate30fps
    
    static let ConfigurationLoaded = Notification.Name("ConfigurationLoaded")
    static let ConfigurationSaved = Notification.Name("ConfigurationSaved")
    
    func load() {
        let defaults = UserDefaults.standard
        autoStartEnabled = defaults.bool(forKey: Constants.AutoStartEnabledKey)
        autoStopEnabled = defaults.bool(forKey: Constants.AutoStopEnabledKey)
        autoStartSpeed = defaults.double(forKey: Constants.AutoStartSpeedKey, defaultValue: Constants.DefaultAutoStartSpeed)
        recordAudio = defaults.bool(forKey: Constants.RecordAudioKey)
        var index = defaults.integer(forKey: Constants.VideoQualityKey)
        videoQuality = availableVideoQualities[index]
        index = defaults.integer(forKey: Constants.GSensorSensibilityKey)
        gsensorSensibility = availableGSensorSensibilities[index]
        frameRate = defaults.int32(forKey: Constants.VideoFrameRateKey, defaultValue: Constants.VideoFrameRate30fps)
        
        NotificationCenter.default.post(name: Config.ConfigurationLoaded, object: self)
    }
    
    func silentSave() {
        let defaults = UserDefaults.standard
        defaults.set(autoStartEnabled, forKey: Constants.AutoStartEnabledKey)
        defaults.set(autoStopEnabled, forKey: Constants.AutoStopEnabledKey)
        defaults.set(autoStartSpeed, forKey: Constants.AutoStartSpeedKey)
        defaults.set(recordAudio, forKey: Constants.RecordAudioKey)
        var index = availableGSensorSensibilities.index(of: gsensorSensibility)
        defaults.set(index, forKey: Constants.GSensorSensibilityKey)
        index = availableVideoQualities.index(of: videoQuality)
        defaults.set(index, forKey: Constants.VideoQualityKey)
        defaults.set(frameRate, forKey: Constants.VideoFrameRateKey)
    }
    
    func save() {
        silentSave()
        NotificationCenter.default.post(name: Config.ConfigurationSaved, object: self)
    }
}

extension UserDefaults {
    
    func double(forKey: String, defaultValue: Double) -> Double {
        var value = self.double(forKey: forKey)
        if value == 0.0 {
            value = defaultValue
        }
        return value
    }
    
    func int32(forKey: String, defaultValue: Int32) -> Int32 {
        var value = Int32(self.integer(forKey: forKey))
        if value == 0 {
            value = defaultValue
        }
        return value
    }
}
