//
//  DriveInfo.swift
//  dr
//
//  Created by Kazuo Tsubaki on 2018/05/08.
//  Copyright © 2018年 Kazuo Tsubaki. All rights reserved.
//  MIT License
//

import Foundation
import CoreLocation

struct DriveInfo {
    var speed: CLLocationSpeed = 0
    var altitude: CLLocationDistance = 0
    var latitude: CLLocationDegrees = 0
    var longitude: CLLocationDegrees = 0
}
