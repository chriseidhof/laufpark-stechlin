//
//  Routing.swift
//  Laufpark
//
//  Created by Chris Eidhof on 19.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import MapKit
#if os(iOS)
    import KDTreeiOS
#else
    import KDTree
#endif

extension Sequence {
    // Creates groups out of the array. Function is called for adjacent element, if true they're in the same group.
    func group(by inSameGroup: (Element, Element) -> Bool) -> [[Element]] {
        return self.reduce(into: [], { result, element in
            if let last = result.last?.last, inSameGroup(last, element) {
                result[result.endIndex-1].append(element)
            } else {
                result.append([element])
            }
        })
    }
}

extension Track {
    func points(between: Coordinate, and: Coordinate) -> [CoordinateWithElevation] {
        let (c1, d1) = points(between: between, and: and, reversed: false)
        let (c2, d2) = points(between: between, and: and, reversed: true)
        return d1 < d2 ? c1 : c2
    }
    
    func points(between: Coordinate, and destination: Coordinate, reversed: Bool) -> ([CoordinateWithElevation], CLLocationDistance) {
        var result: [CoordinateWithElevation] = []
        var started: Bool = false
        let coordinates = (self.coordinates + self.coordinates)
        for c in reversed ? coordinates.reversed() : coordinates {
            if between == c.coordinate {
                started = true
            } else if started && destination == c.coordinate {
                return (result, result.map { CLLocation($0.coordinate.clLocationCoordinate) }.distance)
            } else if started {
                result.append(c)
            }
        }
        fatalError()
    }
}

extension Track {
    func findPoint(closeTo: CLLocationCoordinate2D, tresholdInMeters: Double) -> (index: Int, point: CoordinateWithElevation)? {
        let target = CLLocation(closeTo)
        let withDistance: [(Int, CoordinateWithElevation, CLLocationDistance)] = coordinates.enumerated().map { (i,p) in
            let distance = target.distance(from: CLLocation(p.coordinate.clLocationCoordinate))
            return (i, p, distance)
        }.filter { $0.2 < tresholdInMeters}
        return withDistance.lazy.sorted { $0.2 < $1.2 }.first.map { (index: $0.0, point: $0.1) }
    }
    
    func vertexHelper(coordinate: Coordinate, at index: Int, graph: Graph, reversed: Bool) -> (Coordinate, CLLocationDistance)? {
        let vertices = Set(graph.vertices)
        var startVertex: Coordinate?
        var distanceToStartVertex: CLLocationDistance = 0
        var previous: Coordinate = coordinate
        let indices = Array(0..<index) + Array(0..<index)
        for x in reversed ? indices.reversed() : indices {
            let coord = coordinates[x].coordinate
            defer { previous = coord }
            distanceToStartVertex += CLLocation(coord.clLocationCoordinate).distance(from: CLLocation(previous.clLocationCoordinate))
            if vertices.contains(coord) {
                startVertex = coord
                break
            }
        }
        if let s = startVertex {
            return (s, distanceToStartVertex)
        } else {
            return nil
        }
    }
    
    func vertexBefore(coordinate: Coordinate, at index: Int, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        return vertexHelper(coordinate: coordinate, at: index, graph: graph, reversed: true)
    }
    
    func vertexAfter(coordinate: Coordinate, at index: Int, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        return vertexHelper(coordinate: coordinate, at: index, graph: graph, reversed: false)
    }
}

func readGraph(url: URL) -> Graph? {
    let decoder = JSONDecoder()
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? decoder.decode(Graph.self, from: data)
}

extension Array {
    subscript(safe idx: Int)  -> Element? {
        guard idx >= startIndex && idx < endIndex else { return nil }
        return self[idx]
    }
}

extension Array where Element == [(TrackPoint, overlaps: [Box<Track>])] {
    func mergeSmallGroupsAlt(maxSize: Int) -> [[(TrackPoint, overlaps: [Box<Track>])]] {
        var result: Array = []
        for ix in self.indices {
            let group = self[ix]
            if group.count <= maxSize,
                let previous = self[safe: ix-1], let next = self[safe: ix+1],
                previous[0].overlaps == next[0].overlaps {
                let overlaps = result[result.endIndex-1][0].overlaps
                let newGroup = group.map { ($0.0, overlaps: overlaps) }
                result[result.endIndex-1].append(contentsOf: newGroup)
            } else {
                result.append(group)
            }
        }
        return result
    }
    
}

struct Graph: Codable, Equatable {
    static func ==(lhs: Graph, rhs: Graph) -> Bool {
        return lhs.items.keys == rhs.items.keys // todo hack hack
    }
    
    private(set) var items: [Coordinate:[Entry]] = [:]
    
    struct Entry: Codable, Equatable {
        static func ==(lhs: Graph.Entry, rhs: Graph.Entry) -> Bool {
            return lhs.destination == rhs.destination && lhs.distance == rhs.distance && lhs.trackName == rhs.trackName
        }
        
        let destination: Coordinate
        let distance: CLLocationDistance
        let trackName: String
    }
    
    mutating func add(from: Coordinate, _ entry: Entry) {
        items[from, default: []].append(entry)
        items[entry.destination, default: []].append(Entry(destination: from, distance: entry.distance, trackName: entry.trackName))
    }
    
    var vertices: [Coordinate] { return Array(items.keys) }
    
    func edges(from: Coordinate) -> [Entry] {
        let existing = items[from] ?? []
//        let existingDestinations = Set(existing.map { $0.destination })
//        let c = CLLocation(from.clLocationCoordinate)
////        let squaredTreshold: Double = 150*150
////        let close = items.keys.filter { $0 != from && existingDestinations.contains($0) && CLLocation($0.clLocationCoordinate).squaredDistance(to: c) < squaredTreshold }.map {
////            //let distance =
////            return Entry(destination: $0, distance: c.distance(from: CLLocation($0.clLocationCoordinate)), trackName: "Close")
////        }
//        return close + (items[from] ?? [])
        return existing
    }
}

extension Graph {
    func shortestPath(from source: Coordinate, to target: Coordinate) -> (path: [Entry], distance: CLLocationDistance)? {
        var known: Set<Coordinate> = []
        var distances: [Coordinate:(path: [Entry], distance: CLLocationDistance)] = [:]
        for edge in edges(from: source) {
            distances[edge.destination] = (path: [edge], distance: edge.distance)
        }
        var last = source
        while last != target {
            let smallestKnownDistances = distances.sorted(by: { $0.value.distance < $1.value.distance })
            guard let next = smallestKnownDistances.first(where: { !known.contains($0.key) }) else {
                return nil // no path
            }
            let distVNext = distances[next.key]?.distance ?? .greatestFiniteMagnitude
            for edge in edges(from: next.key) {
                let x = distances[edge.destination]
                let existing = x ?? (path: [edge], distance: .greatestFiniteMagnitude)
                if distVNext + edge.distance < existing.distance {
                    distances[edge.destination] = (path: next.value.path + [edge], distance: distVNext + edge.distance) // todo cse
                }
            }
            last = next.key
            known.insert(next.key)
        }
        return distances[target]
    }
}

func buildGraph(tracks: [Track], url: URL) -> Graph {
    var graph = Graph()
    let tree = KDTree(values: tracks.flatMap { $0.kdPoints })
    
    for t in tracks {
        let joinedPoints: [(TrackPoint, overlaps: [Box<Track>])] = t.kdPoints.enumerated().map { (ix, point) in
            var seen: [Box<Track>] = []
            for neighbor in tree.nearestK(10, to: point) {
                let maxDistance = 20 as Double
                if neighbor.track != point.track && !seen.contains(neighbor.track) && point.distanceInMeters(to: neighbor) < maxDistance {
                    seen.append(neighbor.track)
                }
            }
            seen.sort(by: { $0.unbox.name < $1.unbox.name })
            return (point, overlaps: seen) // this also appends non-overlapping points
        }
        
        let grouped: [[(TrackPoint, overlaps: [Box<Track>])]] = joinedPoints.group(by: { $0.overlaps == $1.overlaps })
//            .mergeSmallGroupsAlt(maxSize: 1)
//            .joined()
//            .group(by: { $0.overlaps == $1.overlaps })
//        grouped.map { ($0.first!.overlaps.map { $0.unbox.name }, $0.count) }.forEach { print($0) }
        for segment in grouped {
            let first = segment[0]
            let from = first.0.point
            let to = segment.last!.0.point
            let distance = segment.map { $0.0.point }.distance
            for t in segment[0].overlaps {
                graph.add(from: Coordinate(from.coordinate), Graph.Entry(destination: Coordinate(to.coordinate), distance: distance, trackName: t.unbox.name))
            }
            
        }
        let last = t.coordinates.last!.coordinate
        let first = t.coordinates[0].coordinate
        graph.add(from: last, Graph.Entry(destination: first, distance: CLLocation(last.clLocationCoordinate).distance(from: CLLocation(first.clLocationCoordinate)), trackName: t.name))
    }
        
    let json = JSONEncoder()
    let result = try! json.encode(graph)
    try! result.write(to: url)
    
    return graph
}
extension Track {
    var kdPoints: [TrackPoint] {
        let box = Box(self)
        return (coordinates + [coordinates[0]]).map { coordAndEle in
            TrackPoint(track: box, point: CLLocation(coordAndEle.coordinate.clLocationCoordinate))
        }
    }
}

struct TrackPoint {
    let track: Box<Track>
    let point: CLLocation
    var mapPoint: MKMapPoint {
        return MKMapPointForCoordinate(point.coordinate)
    }
}

extension TrackPoint: CustomStringConvertible {
    var description: String {
        return "TrackPoint(track: \(track.unbox.name), point: \(point.coordinate))"
    }
}

extension CLLocationCoordinate2D {
    func squaredDistanceApproximation(to other: CLLocationCoordinate2D) -> Double {
        let latMid = (latitude + other.latitude) / 2
        let m_per_deg_lat: Double = 111132.954 - 559.822 * cos(2 * latMid) + 1.175 * cos(4.0 * latMid)
        let m_per_deg_lon: Double = (Double.pi/180) * 6367449 * cos(latMid)
        let deltaLat = fabs(latitude - other.latitude)
        let deltaLon = fabs(longitude - other.longitude)
        return pow(deltaLat * m_per_deg_lat,2) + pow(deltaLon * m_per_deg_lon, 2)
    }
}

extension CLLocation {
    var x: Double {
        return coordinate.latitude/90
    }
    var y: Double {
        return coordinate.longitude/180
    }
    func squaredDistance(to other: CLLocation) -> Double {
        return coordinate.squaredDistanceApproximation(to: other.coordinate)
    }
}



extension TrackPoint: KDTreePoint {
    static let dimensions = 2
    
    func kdDimension(_ dimension: Int) -> Double {
        return dimension == 0 ? mapPoint.x : mapPoint.y
    }
    
    func squaredDistance(to otherPoint: TrackPoint) -> Double {
        // This should really be squared distance according to the coordinate system (and we shouldn't use any methods on CLLocation/MKMapPoint) for the k-d tree to work correctly.
        let dx = mapPoint.x-otherPoint.mapPoint.x
        let dy = mapPoint.y-otherPoint.mapPoint.y
        return dx*dx + dy*dy
    }
    
    func distanceInMeters(to other: TrackPoint) -> Double {
        return MKMetersBetweenMapPoints(self.mapPoint, other.mapPoint)
    }
    
    static func ==(lhs: TrackPoint, rhs: TrackPoint) -> Bool {
        return lhs.track == rhs.track && lhs.point == rhs.point
    }
    
    
}

final class Box<A: Equatable>: Equatable {
    let unbox: A
    init(_ value: A) {
        unbox = value
    }
    
    static func ==(lhs: Box<A>, rhs: Box<A>) -> Bool {
        return lhs.unbox == rhs.unbox
    }
}
