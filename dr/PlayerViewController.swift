//
//  PlayerViewController.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import UIKit
import AVFoundation
import CoreAudio

class PlayerView: UIView {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}

class PlayerViewController: UIViewController {

    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var playerView: PlayerView!
    
    var videoURL: URL!
    var videoAsset: AVAsset!
    var playerItem : AVPlayerItem!
    var videoPlayer: AVPlayer!
    var startButton: UIButton!
    var seekSlider: UISlider!

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.isHidden = true

        playerItem = AVPlayerItem(asset: videoAsset!)
        videoPlayer = AVPlayer(playerItem: playerItem)
        let layer = playerView.layer as! AVPlayerLayer
        layer.videoGravity = AVLayerVideoGravity.resizeAspect
        layer.player = videoPlayer
        
        setupButtons()
        setupSlider()
        
        let interval: Double = Double(0.5 * seekSlider.maximumValue) / Double(seekSlider.bounds.maxX)
        let time: CMTime = CMTimeMakeWithSeconds(interval, Int32(NSEC_PER_SEC))
        videoPlayer.addPeriodicTimeObserver(forInterval: time, queue: nil, using: {time in
            let duration = CMTimeGetSeconds((self.videoPlayer.currentItem?.duration)!)
            let time = CMTimeGetSeconds(self.videoPlayer.currentTime())
            let value = Float(self.seekSlider.maximumValue - self.seekSlider.minimumValue) * Float(time) / Float(duration) + Float(self.seekSlider.minimumValue)
            self.seekSlider.value = value
        })
        
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying(notif:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: videoPlayer.currentItem)
        pauseVideo()
    }

    @objc func playerDidFinishPlaying(notif: Notification) {
        pauseVideo()
        rewindVideoToStart()
    }
    
    @objc func playButtonClicked(sender: UIButton) {
        playVideo()
    }
    
    @objc func stopButtonClicked(sender: UIButton) {
        pauseVideo()
    }
    
    @objc func seekSliderValueChanged(sender: UISlider) {
        videoPlayer.seek(to: CMTimeMakeWithSeconds(Float64(seekSlider.value), Int32(NSEC_PER_SEC)))
    }

    private func playVideo() {
        /*
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Could not activate audio session ", error)
        }
        */
        videoPlayer.play()
        startButton.setImage(UIImage(named: "icon_pause"), for: UIControlState.normal)
        startButton.backgroundColor = UIColor.red
        startButton.addTarget(self, action: #selector(stopButtonClicked(sender:)), for: UIControlEvents.touchUpInside)
    }
    private func pauseVideo() {
        videoPlayer.pause()
        startButton.setImage(UIImage(named: "icon_play"), for: UIControlState.normal)
        startButton.backgroundColor = UIColor.blue
        startButton.addTarget(self, action: #selector(playButtonClicked(sender:)), for: UIControlEvents.touchUpInside)
    }
    
    private func rewindVideoToStart() {
        videoPlayer.seek(to: CMTimeMakeWithSeconds(Float64(0), Int32(NSEC_PER_SEC)))
    }
    
    func setURL(_ url: URL) {
        videoURL = url
        videoAsset = AVAsset(url:videoURL)
    }
    
    @IBAction func dismiss(_ sender: Any) {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func export(_ sender: Any) {
        pauseVideo()
        let av = UIActivityViewController(activityItems: [videoURL], applicationActivities: nil)
        present(av, animated: true, completion: nil)
    }

}

extension PlayerViewController {
    
    private func setupButtons() {
        startButton = UIButton(type: UIButtonType.system)
        startButton.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        startButton.layer.position = CGPoint(x: view.bounds.midX, y: view.bounds.maxY - 30)
        startButton.layer.masksToBounds = true
        startButton.layer.cornerRadius = 16
        startButton.layer.opacity = 0.5
        startButton.tintColor = UIColor.white
        startButton.showsTouchWhenHighlighted = true
        startButton.addTarget(self, action: #selector(playButtonClicked(sender:)), for: UIControlEvents.touchUpInside)
        view.addSubview(startButton)
        
        closeButton.layer.opacity = 0.5
        closeButton.tintColor = UIColor.white
        
        exportButton.layer.opacity = 0.5
        exportButton.tintColor = UIColor.white
    }
    
    private func setupSlider() {
        seekSlider = UISlider()
        seekSlider.frame = CGRect(x:0, y:0, width:view.bounds.maxX / 2 - 40, height: 40)
        seekSlider.layer.position = CGPoint(x: view.bounds.midX + 40 + seekSlider.frame.size.width / 2 , y: view.bounds.maxY - 30)
        seekSlider.layer.opacity = 0.5
        seekSlider.minimumValue = 0
        seekSlider.maximumValue = Float(CMTimeGetSeconds(videoAsset.duration))
        seekSlider.addTarget(self, action: #selector(seekSliderValueChanged(sender:)), for: UIControlEvents.valueChanged)
        view.addSubview(seekSlider)
        
    }
}
