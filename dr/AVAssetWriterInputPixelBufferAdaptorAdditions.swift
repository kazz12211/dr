//
//  AVAssetWriterInputPixelBufferAdaptorAdditions.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/23.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import UIKit
import AVFoundation

extension AVAssetWriterInputPixelBufferAdaptor {
    
    func append(uiImage: UIImage, withPresentationTime presentationTime: CMTime) -> Bool {
        return self.append(cgImage: uiImage.cgImage!, withPresentationTime: presentationTime)
    }
    
    func append(cgImage: CGImage, withPresentationTime presentationTime: CMTime) -> Bool {
        var pxBufferOut: CVPixelBuffer? = nil
        guard let pixelBufferPool = self.pixelBufferPool else {
            return false
        }
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pxBufferOut)
        if status != kCVReturnSuccess {
            return false
        }
        guard let pxBuffer = pxBufferOut else {
            return false;
        }
        CVPixelBufferLockBaseAddress(pxBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let context: CGContext = CGContext(
            data: CVPixelBufferGetBaseAddress(pxBuffer),
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: cgImage.bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue)!
        context.draw(cgImage, in: CGRect(x:0, y:0, width: CGFloat(cgImage.width), height: CGFloat(cgImage.height)))
        CVPixelBufferUnlockBaseAddress(pxBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return self.append(pxBuffer, withPresentationTime: presentationTime)
    }
}
