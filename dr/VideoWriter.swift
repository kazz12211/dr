//
//  VideoWriter.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/10.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import Foundation
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
    var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    var frameNumber: Int64 = 0
    var captureSession: AVCaptureSession!
    var recordingInProgress: Bool = false
    var startTime: CMTime!
    var endTime: CMTime!
    var videoQueue: DispatchQueue!
    var possiblyEnableToEndWriteSession: Bool = false
    var filePath: String!
    var fileURL: URL!
    
    init(session: AVCaptureSession) {
        super.init()
        
        captureSession = session
        
        captureSession.beginConfiguration()
        setupVideoOutput()
        setupAudioOutput()
        setupImageOutput()
        captureSession.commitConfiguration()
    }
    
    func reset() {
        if videoOutput != nil {
            captureSession.removeOutput(videoOutput)
        }
        if audioOutput != nil {
            captureSession.removeOutput(audioOutput)
        }
        if imageOutput != nil {
            captureSession.removeOutput(imageOutput)
        }
        setupVideoOutput()
        setupAudioOutput()
        setupImageOutput()
    }
    
    private func setupVideoOutput() {
        videoOutput = AVCaptureVideoDataOutput()

        if let videoConnection = videoOutput.connection(with: .video) {
            // Videoの向き設定
            if videoConnection.isVideoOrientationSupported {
                videoConnection.videoOrientation = .landscapeRight
            }
            // Video安定化設定
            if videoConnection.isVideoStabilizationSupported {
                videoConnection.preferredVideoStabilizationMode = .cinematic
            }
       }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32BGRA)] as [String : Any]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoQueue = DispatchQueue(label: "VideoQueue")
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
    }
    
    private func setupAudioOutput() {
        if Config.default.recordAudio {
            audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: videoQueue)
            if captureSession.canAddOutput(audioOutput) {
                captureSession.addOutput(audioOutput)
            }
        }
    }
    
    private func setupImageOutput() {
        imageOutput = AVCapturePhotoOutput()
        if let photoConnection = imageOutput.connection(with: .video) {
            photoConnection.videoOrientation = .landscapeRight
        }
        if captureSession.canAddOutput(imageOutput) {
            captureSession.addOutput(imageOutput)
        }
    }
    
    func start() -> Bool {
        if recordingInProgress { return true }
        
        let documentPath = NSHomeDirectory() + "/Documents/"
        filePath = documentPath + Date().filenameFromDate() + ".mp4"
        fileURL = URL(fileURLWithPath: filePath)

        let width = Config.default.videoQuality == Constants.VideoQualityHigh ? 1920 : Config.default.videoQuality == Constants.VideoQualityMedium ? 1280 : 640
        let height = Config.default.videoQuality == Constants.VideoQualityHigh ? 1080 : Config.default.videoQuality == Constants.VideoQualityMedium ? 720 : 480
        let videoInputSettings = [
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCodecKey: AVVideoCodecType.h264
        ] as [String: Any]
        
        videoAssetInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoAssetInput, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)])
        
        do {
            try assetWriter = AVAssetWriter(outputURL: fileURL, fileType: .mp4)
            videoAssetInput.expectsMediaDataInRealTime = true
            assetWriter.add(videoAssetInput)
            if Config.default.recordAudio {
                var acl = AudioChannelLayout()
                bzero(&acl, MemoryLayout<AudioChannelLayout>.size)
                acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
                
                /*
                let audioInputSettings = [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVNumberOfChannelsKey: 1,
                    AVSampleRateKey: 44100,
                    AVEncoderBitRateKey: 64000,
                    AVChannelLayoutKey: Data(bytes: &acl, count: MemoryLayout<AudioChannelLayout>.size)
                ] as [String: Any]
                 */
                let audioInputSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mp4) as! [String: Any]
                // ["AVNumberOfChannelsKey": 1, "AVEncoderBitRatePerChannelKey": 64000, "AVFormatIDKey": 1633772320, "AVSampleRateKey": 44100]
                audioAssetInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
                audioAssetInput.expectsMediaDataInRealTime = true
                assetWriter.add(audioAssetInput)
            } else {
                audioAssetInput = nil
            }
            frameNumber = 0
            endTime = kCMTimeZero
            if assetWriter.startWriting() {
                recordingInProgress = true
                assetWriter.startSession(atSourceTime: kCMTimeZero)
            } else {
                recordingInProgress = false
            }
        } catch {
            print("could not start video recording ", error)
            recordingInProgress = false
        }
        return recordingInProgress
    }
    
    func stop() {
        if !recordingInProgress { return }
        
        if assetWriter != nil {
            videoAssetInput.markAsFinished()
            if audioAssetInput != nil {
                audioAssetInput.markAsFinished()
            }
            self.recordingInProgress = false
            // See Discussion of appendPixelBuffer:withPresentationTime: Apple API Doc.
            while(!possiblyEnableToEndWriteSession) {}
            assetWriter.endSession(atSourceTime: endTime)
            assetWriter.finishWriting {
                //self.videoAssetInput = nil
                //self.audioAssetInput = nil
                /*
                if moveToPhotoAlbum {
                    self.moveVideoToPhotoAlbum()
                }
                 */
            }
        }
    }

    func moveVideoToPhotoAlbum() {
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath) {
            //UISaveVideoAtPathToSavedPhotosAlbum(filePath, self, #selector(videoDidFinishSavingWithError(error:contextInfo:)), nil)
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: self.fileURL)
            }) { (saved, error) in
                if saved {
                    do {
                        try FileManager.default.removeItem(at: self.fileURL)
                    } catch {
                        print("could not remove video file at path \(self.filePath)")
                    }
                }
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
        }) { (success, failure) in
            if success {
                print("Photo saved")
            } else {
                print("Could not save photo: \(String(describing: failure))")
            }
        }
    }
}

// ビデオ保存
extension VideoWriter {
   
    private func uiImageFromSampleBuffer(buffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else {
            return nil
        }
        
        // イメージバッファのロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        // 画像情報を取得
        guard let base = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        let bytesPerRow = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
        let width = UInt(CVPixelBufferGetWidth(imageBuffer))
        let height = UInt(CVPixelBufferGetHeight(imageBuffer))
        
        // ビットマップコンテキスト作成
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitsPerCompornent = 8
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) as UInt32)
        guard let newContext = CGContext(
            data: base,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: Int(bitsPerCompornent),
            bytesPerRow: Int(bytesPerRow),
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        
        // 画像作成
        guard let imageRef = newContext.makeImage() else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }
        let image = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.up)
        
        // イメージバッファのアンロック
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return image
    }
    
    private func composeVideo(buffer: CMSampleBuffer) -> UIImage? {
        guard let image = uiImageFromSampleBuffer(buffer: buffer) else {
            return nil
        }
        let width = image.size.width
        let height = image.size.height
        let font = UIFont.systemFont(ofSize: 14.0)
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        
        UIGraphicsBeginImageContext(image.size)
        
        let timestampRect = CGRect(x: 8, y: height - 38, width: 180, height: 30)
        let locationRect = CGRect(x: width / 2, y: height - 38, width: 240, height: 30)
        let speedRect = CGRect(x: width - 78, y: height - 38, width: 70, height: 30)
        
        let textStyle = NSMutableParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
        let textAttributes = [
            NSAttributedStringKey.font: font,
            NSAttributedStringKey.foregroundColor: UIColor.orange,
            NSAttributedStringKey.paragraphStyle: textStyle
        ]
        
        let timestampText = Date().timestampFromDate()
        let locationText = "".appendingFormat("%.6f %.6f %.0fm", DriveInfo.singleton.latitude, DriveInfo.singleton.longitude, DriveInfo.singleton.altitude)
        let speedText = "".appendingFormat("%.fkm/h", DriveInfo.singleton.speed)
        
        image.draw(in: rect)
        timestampText.draw(in: timestampRect, withAttributes: textAttributes)
        locationText.draw(in: locationRect, withAttributes: textAttributes)
        speedText.draw(in: speedRect, withAttributes: textAttributes)
        
        let composedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return composedImage
    }

}

extension VideoWriter : AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if !CMSampleBufferDataIsReady(sampleBuffer) || !recordingInProgress || assetWriter.status != .writing {
            return
        }
        
        let isVideo = output is AVCaptureVideoDataOutput

        if frameNumber == 0 {
            startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let frameTime = CMTimeSubtract(timestamp, startTime)
        endTime = frameTime

        
        possiblyEnableToEndWriteSession = true
        if isVideo {
            if videoAssetInput.isReadyForMoreMediaData {
                if let composedImage = composeVideo(buffer: sampleBuffer) {
                    possiblyEnableToEndWriteSession = pixelBufferAdaptor.append(uiImage: composedImage, withPresentationTime: frameTime)
                    frameNumber += 1
                }
            }
        } else {
            if audioAssetInput.isReadyForMoreMediaData && frameNumber > 0 {
                self.audioAssetInput.append(sampleBuffer)
            }
        }
    }
}

