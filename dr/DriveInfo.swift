//
//  DriveInfo.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//

import Foundation
import CoreLocation

class DriveInfo: NSObject {
    var speed: CLLocationSpeed!
    var altitude: CLLocationDistance!
    var latitude: CLLocationDegrees!
    var longitude: CLLocationDegrees!
    
    override init() {
        super.init()
        
        speed = 0
        altitude = 0
        latitude = 0
        longitude = 0
    }
}
