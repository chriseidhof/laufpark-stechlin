//
//  Model+MapKit.swift
//  Laufpark
//
//  Created by Chris Eidhof on 12.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation
import MapKit

extension Track {
    var polygon: MKPolygon {
        var coordinates = self.coordinates.map { $0.coordinate.clLocationCoordinate }
        let result = MKPolygon(coordinates: &coordinates, count: coordinates.count)
        return result
    }
    
    typealias ElevationProfile = [(distance: CLLocationDistance, elevation: Double)]
    var elevationProfile: ElevationProfile {
        let result = coordinates.diffed { l, r in
            (CLLocation(l.coordinate.clLocationCoordinate).distance(from: CLLocation(r.coordinate.clLocationCoordinate)), r.elevation)
        }
        var distanceTotal = 0 as CLLocationDistance
        return result.map { pair in
            defer { distanceTotal += pair.0 }
            return (distance: distanceTotal, elevation: pair.1)
        }
    }
}

extension MKPointAnnotation {
    convenience init(coordinate: CLLocationCoordinate2D, title: String) {
        self.init()
        self.coordinate = coordinate
        self.title = title
    }
}
