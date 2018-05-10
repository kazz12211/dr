//
//  VideoWriter.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/10.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import Foundation
import AVFoundation

class VideoWriter : NSObject {
    
    var videoOutput: AVCaptureVideoDataOutput!
    var audioOutput: AVCaptureAudioDataOutput!
    var assetWriter: AVAssetWriter!
    var videoAssetInput: AVAssetWriterInput!
    var audioAssetInput: AVAssetWriterInput!
    var pixelBuffer: AVAssetWriterInputPixelBufferAdaptor!
    var frameNumber: Int64 = 0
    var config: Config!
    var captureSession: AVCaptureSession!
    var recordingInProgress: Bool = false

    init(session: AVCaptureSession) {
        super.init()
        
        captureSession = session
        config = Config.default
        
        setupVideoOutput()
        setupAudioOutput()
    }
    
    func reset() {
        recordingInProgress = false
        if videoOutput != nil {
            videoOutput.setSampleBufferDelegate(nil, queue: DispatchQueue.main)
            captureSession.removeOutput(videoOutput)
            videoOutput = nil
        }
        if audioOutput != nil {
            audioOutput.setSampleBufferDelegate(nil, queue: DispatchQueue.main)
            captureSession.removeOutput(audioOutput)
            audioOutput = nil
        }
        setupVideoOutput()
        setupAudioOutput()
    }
    
    private func setupVideoOutput() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)] as [String : Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureSession.addOutput(videoOutput)
    }
    
    private func setupAudioOutput() {
        if config.recordAudio {
            audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
            captureSession.addOutput(audioOutput)
        }
    }
    
    func start(_ url: URL) -> Bool {
        let width = config.videoQuality == Constants.VideoQualityHigh ? 1920 : config.videoQuality == Constants.VideoQualityMedium ? 1280 : 640
        let height = config.videoQuality == Constants.VideoQualityHigh ? 1080 : config.videoQuality == Constants.VideoQualityMedium ? 720 : 480
        let videoInputSettings = [AVVideoWidthKey: width, AVVideoHeightKey: height, AVVideoCodecKey: AVVideoCodecType.h264] as [String:Any]
        
        videoAssetInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        pixelBuffer = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoAssetInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        
        frameNumber = 0
        
        do {
            try assetWriter = AVAssetWriter(outputURL: url, fileType: .mp4)
            videoAssetInput.expectsMediaDataInRealTime = true
            assetWriter.add(videoAssetInput)
            if config.recordAudio {
                let audioInputSettings = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVNumberOfChannelsKey: 1, AVSampleRateKey: 44100, AVEncoderBitRateKey: 128000]
                audioAssetInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
                audioAssetInput.expectsMediaDataInRealTime = true
                assetWriter.add(audioAssetInput)
            }
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: kCMTimeZero)
            recordingInProgress = true
            return true
        } catch {
            print("could not start video recording ", error)
            return false
        }
    }
    
    func stop() {
        if assetWriter != nil {
            videoAssetInput.markAsFinished()
            if audioAssetInput != nil {
                audioAssetInput.markAsFinished()
            }
            assetWriter.endSession(atSourceTime: CMTimeMake(frameNumber, config.frameRate))
            assetWriter.finishWriting {
                self.pixelBuffer = nil
                self.videoAssetInput = nil
                self.audioAssetInput = nil
                self.recordingInProgress = false
            }
        }
    }

}

extension VideoWriter : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !recordingInProgress {
            return
        }
        
        let isVideo = output is AVCaptureVideoDataOutput
        
        if isVideo {
            if videoAssetInput.isReadyForMoreMediaData {
                guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                    
                }
                pixelBuffer.append(imageBuffer, withPresentationTime: CMTimeMake(frameNumber, config.frameRate))
                frameNumber += 1
            }
        } else {
            if audioAssetInput.isReadyForMoreMediaData {
                audioAssetInput.append(sampleBuffer)
            }
        }
    }
}
