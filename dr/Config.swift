//
//  Config.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation
import AVFoundation

struct Constants {
    static let GSensorSensibilityKey = "GSenserSensibility"
    static let AutoStartEnabledKey = "AutoStartEnabled"
    static let AutoStopEnabledKey = "AutoStopEnabled"
    static let VideoQualityKey = "VideoQuality"
    static let RecordAudioKey = "RecordAudio"
    static let GSensorStrong = 4.0
    static let GSensorMedium = 2.8
    static let GSensorWeak = 1.8
    static let AutoStartSpeedKey = "AutoStartSpeed"
    static let DefaultAutoStartSpeed = 10.0
    static let VideoQualityHigh = AVCaptureSession.Preset.hd1920x1080
    static let VideoQualityMedium = AVCaptureSession.Preset.hd1280x720
    static let VideoQualityLow = AVCaptureSession.Preset.vga640x480
}

class Config: NSObject {
    
    var gsensorSensibility: Double = Constants.GSensorStrong
    var autoStartEnabled: Bool = false
    var autoStopEnabled: Bool = false
    var autoStartSpeed = Constants.DefaultAutoStartSpeed
    var recordAudio: Bool = false
    var videoQuality: AVCaptureSession.Preset = Constants.VideoQualityMedium
    var availableVideoQualities: [AVCaptureSession.Preset] = [Constants.VideoQualityHigh, Constants.VideoQualityMedium, Constants.VideoQualityLow]
    var availableGSensorSensibilities:[Double] = [Constants.GSensorStrong, Constants.GSensorMedium, Constants.GSensorWeak]
    
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
        
        NotificationCenter.default.post(name: Config.ConfigurationLoaded, object: self)
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(autoStartEnabled, forKey: Constants.AutoStartEnabledKey)
        defaults.set(autoStopEnabled, forKey: Constants.AutoStopEnabledKey)
        defaults.set(autoStartSpeed, forKey: Constants.AutoStartSpeedKey)
        defaults.set(recordAudio, forKey: Constants.RecordAudioKey)
        var index = availableGSensorSensibilities.index(of: gsensorSensibility)
        defaults.set(index, forKey: Constants.GSensorSensibilityKey)
        index = availableVideoQualities.index(of: videoQuality)
        defaults.set(index, forKey: Constants.VideoQualityKey)
        
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
}
