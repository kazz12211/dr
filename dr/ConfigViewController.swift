//
//  ConfigViewController.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit

class ConfigViewController: UIViewController {

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var autoStartSwitch: UISwitch!
    @IBOutlet weak var autoStartSpeedField: UITextField!
    @IBOutlet weak var autoStopSwitch: UISwitch!
    @IBOutlet weak var gsensorSegmentedControl: UISegmentedControl!
    @IBOutlet weak var videoQualitySegmentedControl: UISegmentedControl!
    @IBOutlet weak var frameRateSegmentedControl: UISegmentedControl!
    @IBOutlet weak var recordAudioSwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Config.default.load()
        
        autoStartSwitch.setOn(Config.default.autoStartEnabled, animated: false)
        autoStopSwitch.setOn(Config.default.autoStopEnabled, animated: false)
        gsensorSegmentedControl.selectedSegmentIndex = Config.default.availableGSensorSensibilities.index(of: Config.default.gsensorSensibility)!
        videoQualitySegmentedControl.selectedSegmentIndex = Config.default.availableVideoQualities.index(of: Config.default.videoQuality)!
        frameRateSegmentedControl.selectedSegmentIndex = Config.default.availableFrameRates.index(of: Config.default.frameRate)!
        recordAudioSwitch.setOn(Config.default.recordAudio, animated: false)
        autoStartSpeedField.text = "".appendingFormat("%.0f", Config.default.autoStartSpeed)
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(contentViewTapped)))
    }

    @IBAction func autoStartSwitched(_ sender: UISwitch) {
        contentViewTapped()
        Config.default.autoStartEnabled = sender.isOn
    }
    
    @IBAction func autoStopSwitched(_ sender: UISwitch) {
        contentViewTapped()
        Config.default.autoStopEnabled = sender.isOn
    }
    
    @IBAction func gsensorChanged(_ sender: UISegmentedControl) {
        contentViewTapped()
        Config.default.gsensorSensibility = Config.default.availableGSensorSensibilities[sender.selectedSegmentIndex]
    }
    
    @IBAction func videoQualityChanged(_ sender: UISegmentedControl) {
        contentViewTapped()
        Config.default.videoQuality = Config.default.availableVideoQualities[sender.selectedSegmentIndex]
    }
    
    @IBAction func frameRateChanged(_ sender: UISegmentedControl) {
        contentViewTapped()
        Config.default.frameRate = Config.default.availableFrameRates[sender.selectedSegmentIndex]
    }
    
    @IBAction func recordAudioSwitched(_ sender: UISwitch) {
        contentViewTapped()
        Config.default.recordAudio = sender.isOn
    }
    
    @IBAction func autoStartSpeedChanged(_ sender: UITextField) {
        guard let val = sender.text else {
            Config.default.autoStartSpeed = Constants.DefaultAutoStartSpeed
            return
        }
        Config.default.autoStartSpeed = NSString(string: val).doubleValue
    }
    
    @IBAction func dismiss(_ sender: Any) {
        Config.default.save()
        dismiss(animated: true) {
        }
    }
}

extension ConfigViewController {
    
    @objc private func contentViewTapped() {
        if autoStartSpeedField.isFirstResponder {
            autoStartSpeedField.resignFirstResponder()
        }
    }
}

