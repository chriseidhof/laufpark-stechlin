//
//  Model.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation
import CoreLocation

enum Color {
    case red
    case turquoise
    case brightGreen
    case violet
    case purple
    case green
    case beige
    case blue
    case brown
    case yellow
    case gray
    case lightBlue
    case lightBrown
    case orange
    case pink
    case lightPink
}

extension CLLocation {
    convenience init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

extension Sequence where SubSequence: Sequence, SubSequence.Element == Element {
    func diffed() -> AnySequence<(Element, Element)> {
        return AnySequence(zip(self, self.dropFirst()))
    }
    
    func diffed<Result>(with combine: (Element, Element) -> Result) -> [Result] {
        return zip(self, self.dropFirst()).map { combine($0.0, $0.1) }
    }

}

struct Track {
    let coordinates: [(CLLocationCoordinate2D, elevation: Double)]
    let color: Color
    let number: Int
    
    var distance: CLLocationDistance {
        guard let first = coordinates.first else { return 0 }
        
        let (result, _) = coordinates.reduce(into: (0 as CLLocationDistance, previous: CLLocation(first.0))) { r, coord in
            let loc = CLLocation(coord.0)
            let distance = loc.distance(from: r.1)
            r.1 = loc
            r.0 += distance
        }
        return result
    }
    
    var ascent: Double {
        let elevations = coordinates.lazy.map { $0.elevation }
        return elevations.diffed(with: -).filter({ $0 > 0 }).reduce(0,+)
    }

}

extension Track {
    init(color: Color, number: Int, points: [Point]) {
        self.color = color
        self.number = number
        coordinates = points.map { point in
            (CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon), elevation: point.ele)
        }
    }
}

struct Point {
    let lat: Double
    let lon: Double
    let ele: Double
}

final class TrackReader: NSObject, XMLParserDelegate {
    var inTrk = false

    var points: [Point] = []
    var pending: (lat: Double, lon: Double)?
    var elementContents: String = ""
    
    init?(url: URL) {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        super.init()
        parser.delegate = self
        guard parser.parse() else { return nil }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        elementContents += string
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        guard inTrk else {
            inTrk = elementName == "trk"
            return
        }
        if elementName == "trkpt" {
            guard let latStr = attributeDict["lat"], let lat = Double(latStr),
                let lonStr = attributeDict["lon"], let lon = Double(lonStr) else { return }
            pending = (lat: lat, lon: lon)
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        defer { elementContents = "" }
        if elementName == "trk" {
            inTrk = false
        } else if elementName == "ele" {
            let elementText = elementContents.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let p = pending, let ele = Double(elementText) else { return }
            points.append(Point(lat: p.lat, lon: p.lon, ele: ele))
        }
    }
}
