//
//  PlaylistCell.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import UIKit
import AVFoundation

class PlaylistCell : UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var thumbnailView: UIImageView!
    
    func setURL(_ url: URL) {
        let asset = AVAsset(url: url)
        nameLabel.text = timestampFromURL(url)
        timeLabel.text = durationFromAsset(asset)
        sizeLabel.text = sizeFromURL(url)
        thumbnailView.image = thumbnailFromAsset(asset)
    }
    
    private func timestampFromURL(_ url: URL) -> String {
        let filename = url.lastPathComponent
        let fn = String(filename[filename.index(filename.startIndex, offsetBy: 0)...filename.index(filename.endIndex, offsetBy: -5)])
        if let date = fn.dateFromFilename(fn) {
            return date.timestampFromDate()
        } else {
            return ""
        }
    }
    
    private func durationFromAsset(_ asset: AVAsset) -> String {
        var seconds = UInt64(asset.duration.seconds)
        var minutes = UInt64(0)
        var hours = UInt64(0)
        if(seconds >= 60) {
            minutes = seconds / 60
            seconds = seconds % 60
        }
        if(minutes >= 60) {
            hours = minutes / 60
            minutes = minutes % 60
        }
        if hours > 0 {
            return "\(hours)時間\(minutes)分\(seconds)秒"
        }
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    private func sizeFromURL(_ url: URL) -> String {
        let kb = fileSizeFromURL(url).int64Value;
        if kb < 1024 {
            return "".appendingFormat("\(kb) KB")
        }
        if kb < (1024 * 1024) {
            let mb = kb / 1024
            return "".appendingFormat("\(mb) MB")
        }
        let mb = (kb / 1024) % 1024
        let gb = kb / (1024 * 1024)
        return "".appendingFormat("\(gb).\(mb) GB")
    }
    
    private func fileSizeFromURL(_ url: URL) -> NSNumber {
        let filePath = NSHomeDirectory() + "/Documents/" + url.lastPathComponent
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
            let bytes: NSNumber = attributes[FileAttributeKey.size] as! NSNumber
            return NSNumber(value:bytes.int64Value / 1024)
        } catch {
        }
        return NSNumber(value: 0)
    }
    
    private func thumbnailFromAsset(_ asset: AVAsset) -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.maximumSize = thumbnailView.frame.size
        do {
            let thumbnail = try generator.copyCGImage(at: asset.duration, actualTime: nil)
            return UIImage(cgImage: thumbnail)
        } catch {
            return UIImage(named: "video-camera")
        }
    }

}
