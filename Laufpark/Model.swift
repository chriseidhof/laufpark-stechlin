//
//  Model.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation
import CoreLocation

struct POI {
    let location: CLLocationCoordinate2D
    let name: String
    
    static let all: [POI] = [
        POI(location: CLLocationCoordinate2D(latitude: 53.187240, longitude: 13.088585), name: "Gasthaus Haveleck"),
        POI(location: CLLocationCoordinate2D(latitude: 53.191610, longitude: 13.159954), name: "Jugendherberge Ravensbrück"),
        POI(location: CLLocationCoordinate2D(latitude: 53.179984, longitude: 12.899209), name: "Hotel & Ferienanlage Precise Resort Marina Wolfsbruch"),
        POI(location: CLLocationCoordinate2D(latitude: 52.966637,longitude: 13.281789), name: "Pension Lindenhof"),
        POI(location: CLLocationCoordinate2D(latitude: 53.091639, longitude: 13.093251), name: "Gut Zernikow"),
        POI(location: CLLocationCoordinate2D(latitude: 53.031421, longitude: 13.30988), name: "Ziegeleipark Mildenberg"),
        POI(location: CLLocationCoordinate2D(latitude: 53.112691, longitude: 13.104139), name: "Hotel und Restaurant \"Zum Birkenhof\""),
        POI(location: CLLocationCoordinate2D(latitude: 53.167976, longitude: 13.23558), name: "Campingpark Himmelpfort"),
        POI(location: CLLocationCoordinate2D(latitude: 53.115591, longitude: 12.889571), name: "Maritim Hafenhotel Reinsberg"),
        POI(location: CLLocationCoordinate2D(latitude: 53.175714, longitude: 13.232601), name: "Ferienwohnung in der Mühle Himmelpfort"),
        POI(location: CLLocationCoordinate2D(latitude: 53.115685, longitude: 13.25494), name: "Gut Boltenhof"),
        POI(location: CLLocationCoordinate2D(latitude: 53.053821, longitude: 13.083495), name: "Werkshof Wolfsruh")
    ]
}

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
    let name: String
    
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

    func point(at distance: CLLocationDistance) -> CLLocation? {
        var current = 0 as CLLocationDistance
        for (p1, p2) in coordinates.lazy.map({ CLLocation($0.0) }).diffed() {
            current += p2.distance(from: p1)
            if current > distance { return p2 }
        }
        return nil
    }
}

extension Track: Equatable {
    static func ==(l: Track, r: Track) -> Bool {
        return l.name == r.name // todo
    }
}

extension Track {
    init(color: Color, number: Int, name: String, points: [Point]) {
        self.color = color
        self.number = number
        self.name = name
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

extension String {
    func remove(prefix: String) -> String {
        return String(dropFirst(prefix.count))
    }
}

final class TrackReader: NSObject, XMLParserDelegate {
    var inTrk = false

    var points: [Point] = []
    var pending: (lat: Double, lon: Double)?
    var elementContents: String = ""
    var name = ""
    
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
        var trimmed: String { return elementContents.trimmingCharacters(in: .whitespacesAndNewlines) }
        if elementName == "trk" {
            inTrk = false
        } else if elementName == "ele" {
            guard let p = pending, let ele = Double(trimmed) else { return }
            points.append(Point(lat: p.lat, lon: p.lon, ele: ele))
        } else if elementName == "name" && inTrk {
            name = trimmed.remove(prefix: "Laufpark Stechlin - Wabe ")
        }
    }
}
