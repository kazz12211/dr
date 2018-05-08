//
//  FilenameUtil.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation

extension Date {
    
    func filenameFromDate() -> String {
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        return filenameFormatter.string(from: self)
    }
    
    func timestampFromDate() -> String {
        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return timestampFormatter.string(from: self)
    }
}

extension String {
    
    func dateFromFilename(_ filename: String) -> Date? {
        let filenameFormatter = DateFormatter()
        filenameFormatter.dateFormat = "yyyyMMdd_HHmmss"
        return filenameFormatter.date(from: filename)
    }
}
