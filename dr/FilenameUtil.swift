//
//  FilenameUtil.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import Foundation

class Formatters : NSObject {
    let filenameFormatter = DateFormatter()
    let timestampFormatter = DateFormatter()
    
    static let `default` = Formatters()
    
    override init() {
        super.init()
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
    }
}

extension Date {
    
    func filenameFromDate() -> String {
        return Formatters.default.filenameFormatter.string(from: self)
    }
    
    func timestampFromDate() -> String {
        return Formatters.default.timestampFormatter.string(from: self)
    }
}

extension String {
    
    func dateFromFilename(_ filename: String) -> Date? {
        return Formatters.default.filenameFormatter.date(from: filename)
    }
}
