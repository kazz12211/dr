//
//  VideoWriter.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/10.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import UIKit
import AVFoundation
import Photos

class VideoWriter : NSObject {
    
    var videoOutput: AVCaptureVideoDataOutput!
    var audioOutput: AVCaptureAudioDataOutput!
    var imageOutput: AVCapturePhotoOutput!
    var assetWriter: AVAssetWriter!
    var videoAssetInput: AVAssetWriterInput!
    var audioAssetInput: AVAssetWriterInput!
    var pixelBuffer: AVAssetWriterInputPixelBufferAdaptor!
    var frameNumber: Int64 = 0
    var config: Config!
    var captureSession: AVCaptureSession!
    var recordingInProgress: Bool = false
    var startTime: CMTime!
    var endTime: CMTime!

    init(session: AVCaptureSession) {
        super.init()
        
        captureSession = session
        config = Config.default
        
        setupVideoOutput()
        setupAudioOutput()
        setupImageOutput()
    }
    
    
    private func setupVideoOutput() {
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)] as [String : Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        let queue = DispatchQueue(label: "VideoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.addOutput(videoOutput)
        
        // Video安定化設定
        if let videoConnection: AVCaptureConnection = videoOutput.connection(with: .video) {
            if videoConnection.isVideoStabilizationSupported {
                videoConnection.preferredVideoStabilizationMode = .cinematic
            }
        }
    }
    
    private func setupAudioOutput() {
        if config.recordAudio {
            audioOutput = AVCaptureAudioDataOutput()
            let queue = DispatchQueue(label: "AudioQueue")
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            captureSession.addOutput(audioOutput)
        }
    }
    
    private func setupImageOutput() {
        imageOutput = AVCapturePhotoOutput()
        captureSession.addOutput(imageOutput)
        if let photoConnection = imageOutput.connection(with: .video) {
            photoConnection.videoOrientation = .landscapeRight
        }
    }
    
    func start() -> Bool {
        if recordingInProgress { return true }
        
        let documentPath = NSHomeDirectory() + "/Documents/"
        let filePath = documentPath + Date().filenameFromDate() + ".mp4"
        let url = URL(fileURLWithPath: filePath)

        let width = config.videoQuality == Constants.VideoQualityHigh ? 1920 : config.videoQuality == Constants.VideoQualityMedium ? 1280 : 640
        let height = config.videoQuality == Constants.VideoQualityHigh ? 1080 : config.videoQuality == Constants.VideoQualityMedium ? 720 : 480
        let videoInputSettings = [
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCodecKey: AVVideoCodecType.h264
        ] as [String: Any]
        
        videoAssetInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        pixelBuffer = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoAssetInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        
        frameNumber = 0
        
        do {
            try assetWriter = AVAssetWriter(outputURL: url, fileType: .mp4)
            videoAssetInput.expectsMediaDataInRealTime = true
            assetWriter.add(videoAssetInput)
            if config.recordAudio {
                var acl = AudioChannelLayout()
                bzero(&acl, MemoryLayout<AudioChannelLayout>.size)
                acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
                
                let audioInputSettings = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 64000,
                    AVChannelLayoutKey: Data(bytes: &acl, count: MemoryLayout<AudioChannelLayout>.size)
                ] as [String: Any]
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
        if !recordingInProgress { return }
        
        if assetWriter != nil {
            videoAssetInput.markAsFinished()
            if audioAssetInput != nil {
                audioAssetInput.markAsFinished()
            }
            //assetWriter.endSession(atSourceTime: CMTimeMake(frameNumber, config.frameRate))
            assetWriter.endSession(atSourceTime: endTime)
            assetWriter.finishWriting {
                //self.pixelBuffer = nil
                self.videoAssetInput = nil
                self.audioAssetInput = nil
                self.recordingInProgress = false
            }
        }
    }

    
}

// 静止画保存
extension VideoWriter {
    
    func takeStillImage() {
        let capturePhotoSettings = AVCapturePhotoSettings.init(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        capturePhotoSettings.flashMode = .off
        capturePhotoSettings.isHighResolutionPhotoEnabled = false
        if imageOutput.isStillImageStabilizationSupported {
            capturePhotoSettings.isAutoStillImageStabilizationEnabled = true
        }
        imageOutput.capturePhoto(with: capturePhotoSettings, delegate: self)
    }

}

extension VideoWriter : AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        PHPhotoLibrary.shared().performChanges({
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .photo, data: photo.fileDataRepresentation()!, options: nil)
        }) { (success, error) in
            if success {
                print("Photo saved")
            } else {
                print("Could not save photo: ", error)
            }
        }
    }
}

// ビデオ保存
extension VideoWriter {
   
    private func uiImageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage {
        let imageBuffer = CMSampleBufferGetImageBuffer(buffer)!
        
        // イメージバッファのロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // 画像情報を取得
        let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
        let width = UInt(CVPixelBufferGetWidth(imageBuffer))
        let height = UInt(CVPixelBufferGetHeight(imageBuffer))
        
        // ビットマップコンテキスト作成
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerCompornent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        let newContext = CGContext(data: base, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent), bytesPerRow: Int(bytesPerRow), space: colorSpace, bitmapInfo: bitmapInfo.rawValue)! as CGContext
        
        // 画像作成
        let imageRef = newContext.makeImage()!
        let image = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.up)
        
        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return image
    }
    
    private func pixelBufferFromUIImage(image: UIImage) -> CVPixelBuffer {
        let cgImage = image.cgImage!
        let options = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true]
        var pxBuffer: CVPixelBuffer? = nil
        let width = cgImage.width
        let height = cgImage.height
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, options as CFDictionary?, &pxBuffer)
        CVPixelBufferLockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pxData = CVPixelBufferGetBaseAddress(pxBuffer!)!
        let bitsPerComponent: size_t = 8
        let bytePerRow: size_t = 4 * width
        let rgbColorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB()
        let context: CGContext = CGContext(data: pxData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytePerRow, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.draw(cgImage, in: CGRect(x:0, y:0, width: CGFloat(width), height: CGFloat(height)))
        CVPixelBufferUnlockBaseAddress(pxBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pxBuffer!
    }
    
    private func composeVideo(buffer: CMSampleBuffer) -> CVPixelBuffer {
        let image = uiImageFromSampleBuffer(buffer: buffer)
        let width = image.size.width
        let height = image.size.height
        let font = UIFont.systemFont(ofSize: 14.0)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        UIGraphicsBeginImageContext(image.size)
        
        let timestampRect = CGRect(x: 8, y: height - 38, width: 180, height: 30)
        let locationRect = CGRect(x: width / 2, y: height - 38, width: 180, height: 30)
        let speedRect = CGRect(x: width - 78, y: height - 38, width: 70, height: 30)
        
        let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        let textAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: UIColor.orange,
            NSAttributedStringKey.paragraphStyle: textStyle
        ]
        
        let timestampText = Date().timestampFromDate()
        let locationText = "".appendingFormat("%.4f %.4f %.0fm", DriveInfo.singleton.latitude, DriveInfo.singleton.longitude, DriveInfo.singleton.altitude)
        let speedText = "".appendingFormat("%.fkm/h", DriveInfo.singleton.speed)
        
        image.draw(in: rect)
        timestampText.draw(in: timestampRect, withAttributes: textAttributes)
        locationText.draw(in: locationRect, withAttributes: textAttributes)
        speedText.draw(in: speedRect, withAttributes: textAttributes)
        
        let composedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return pixelBufferFromUIImage(image: composedImage!)
    }

}

extension VideoWriter : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !CMSampleBufferDataIsReady(sampleBuffer) || !recordingInProgress {
            return
        }
        
        if frameNumber == 0 {
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameTime = CMTimeSubtract(timestamp, startTime)

        let isVideo = output is AVCaptureVideoDataOutput
        
        if isVideo {
            if videoAssetInput.isReadyForMoreMediaData {
                let pxBuffer:CVPixelBuffer = composeVideo(buffer: sampleBuffer)
                //guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
                //pixelBuffer.append(imageBuffer, withPresentationTime: CMTimeMake(frameNumber, config.frameRate))
                pixelBuffer.append(pxBuffer, withPresentationTime: frameTime)
                //pixelBuffer.append(pxBuffer, withPresentationTime: CMTimeMake(frameNumber, config.frameRate))
                frameNumber += 1
            }
        } else {
            if audioAssetInput.isReadyForMoreMediaData {
                audioAssetInput.append(sampleBuffer)
            }
        }
        endTime = frameTime
    }
}

