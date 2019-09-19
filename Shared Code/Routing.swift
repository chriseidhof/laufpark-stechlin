//
//  Routing.swift
//  Laufpark
//
//  Created by Chris Eidhof on 19.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import MapKit

struct Route: Equatable, Codable {
    let startingPoint: CoordinateAndTrack
    var points: [CoordinateAndTrack] = []
    
    init(track: Track, coordinate: Coordinate) {
        startingPoint = CoordinateAndTrack(coordinate: coordinate, track: track, pathFromPrevious: nil)
    }
    
    mutating func add(coordinate: Coordinate, inTrack track: Track, graph: Graph) {
        let previous = points.last ?? startingPoint
        
        let path: Path? = graph.shortestPath(from: previous.coordinate, to: coordinate).map {
            Path(entries: $0.path, distance: $0.distance)
        }
        let result = CoordinateAndTrack(coordinate: coordinate, track: track, pathFromPrevious: path)
        points.append(result)
    }
    
    var wayPoints: [Coordinate] {
        return [startingPoint.coordinate] + points.map { $0.coordinate }
    }
    
    var segments: [(Coordinate, Coordinate)] {
        let coordinates = points.map { $0.coordinate }
        return Array(zip([startingPoint.coordinate] + coordinates, coordinates))
    }
    
    var distance: Double {
        return points.map { $0.pathFromPrevious?.distance ?? 0 }.reduce(into: 0, +=)
    }
    
    func allPoints(tracks: [Track]) -> [CoordinateWithElevation] {
        var result: [CoordinateWithElevation] = [startingPoint.track.interpolatedPoint(for: startingPoint.coordinate)!]
        for wayPoint in points {
            if let p = wayPoint.pathFromPrevious?.entries {
                for entry in p {
                    if entry.trackName != "Close" {
                        let track = tracks.first { $0.name == entry.trackName }!
                        result += track.points(between: result.last!.coordinate, and: entry.destination)
                    }
                    let dest = CoordinateWithElevation(coordinate: entry.destination, elevation: result.last!.elevation) // todo lookup
                    result.append(dest)
                    
                }
            }
            var wayp = wayPoint.track.interpolatedPoint(for: wayPoint.coordinate)
            if wayp == nil {
                print("error")
                wayp = CoordinateWithElevation(coordinate: wayPoint.coordinate, elevation: result.last?.elevation ?? 0)
            }
            
            result.append(wayp!)
        }
        return result
    }
    
    mutating func removeLastWaypoint() {
        guard !points.isEmpty else {
            return
        }
        points.removeLast()
    }
}

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

typealias Segment = (CLLocationCoordinate2D, CLLocationCoordinate2D)

extension CLLocationCoordinate2D {
    func amount(segment: Segment) -> Double {
        let deltaLat = segment.1.latitude - segment.0.latitude
        let deltaLon = segment.1.longitude - segment.0.longitude
        
        let u = CLLocationDegrees(
            (latitude - segment.0.latitude) *
                (segment.1.latitude - segment.0.latitude) +
                (longitude - segment.0.longitude) *
                (segment.1.longitude - segment.0.longitude)
            ) / (pow(deltaLat, 2) + pow(deltaLon, 2))
        
        
        return max(0, min(u,1)) // clamp to 0...1
    }
    // stolen from https://github.com/mhawkins/GCRDPProcessor/blob/master/GCRDPProcessor/GCRDPProcessor.m
    func closestPointOn(segment: Segment) -> CLLocationCoordinate2D {
        let deltaLat = segment.1.latitude - segment.0.latitude
        let deltaLon = segment.1.longitude - segment.0.longitude
        
        let u = amount(segment: segment)
        return CLLocationCoordinate2D(
            latitude: segment.0.latitude + u * deltaLat,
            longitude: segment.0.longitude + u * deltaLon
        )
    }
    
    func squaredDistance(to segment: Segment) -> Double {
        return closestPointOn(segment: segment).squaredDistanceApproximation(to: self)
    }
}

extension Array {
    func douglasPeucker(coordinate: (Element) -> CLLocationCoordinate2D, squaredEpsilonInMeters e: Double) -> [Element] {
        guard count > 2 else { return self }
        
        var distanceMax: Double = 0
        var currentIndex = startIndex
        let indexBeforEnd = index(before: endIndex)
        let segment = (coordinate(self[startIndex]), coordinate(self[indexBeforEnd]))
        for index in 1..<indexBeforEnd {
            let current = self[index]
            let distance = coordinate(current).squaredDistance(to: segment)
            if distance > distanceMax {
                distanceMax = distance
                currentIndex = index
            }
        }
        
        if distanceMax > e {
            var a1 = Array(self[0...currentIndex]).douglasPeucker(coordinate: coordinate, squaredEpsilonInMeters: e)
            let a2 = Array(self[currentIndex..<endIndex]).douglasPeucker(coordinate:coordinate, squaredEpsilonInMeters: e)
            a1.removeLast()
            return a1 + a2
        } else {
            return [self[startIndex], self[indexBeforEnd]]
        }
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
        
        // todo check segments?
        if let _ = coordinates.index(where: { $0.coordinate == between }) {
            return ([], between.clLocationCoordinate.squaredDistanceApproximation(to: destination.clLocationCoordinate).squareRoot())
        } else if let _ = coordinates.index(where: { $0.coordinate == destination }) {
            return ([], between.clLocationCoordinate.squaredDistanceApproximation(to: destination.clLocationCoordinate).squareRoot())
        }
        
        print("TODO")
        
        fatalError()
    }
}

typealias SegmentWithElevation = (CoordinateWithElevation, CoordinateWithElevation)

extension Track {
    var segments: AnySequence<Segment> {
        let coordinates = self.coordinates.map { $0.coordinate.clLocationCoordinate }
        return AnySequence(zip(coordinates, coordinates.dropFirst() + [coordinates.first!]))
    }
    
    var segmentsWithElevation: AnySequence<SegmentWithElevation> {
        let coordinates = self.coordinates
        return AnySequence(zip(coordinates, coordinates.dropFirst() + [coordinates.first!]))
    }
    
    func segment(closeTo point: CLLocationCoordinate2D, maxDistance: Double) -> Segment? {
        let distance = maxDistance*maxDistance
        return segments.first {
            point.squaredDistance(to: $0) < distance
        }
    }
    
    func segment(closestTo point: CLLocationCoordinate2D, maxDistance: Double) -> Segment? {
        let distance = maxDistance*maxDistance
        return segments.lazy.map {
            (segment: $0, distance: point.squaredDistance(to: $0))
        }.filter { $0.distance < distance }.sorted(by: { $0.distance < $1.distance }).first.map { $0.segment }
    }
    
    func segmentWithElevation(closestTo point: CLLocationCoordinate2D, maxDistance: Double) -> SegmentWithElevation? {
        let distance = maxDistance*maxDistance
        return segmentsWithElevation.lazy.map {
            (segment: $0, distance: point.squaredDistance(to: ($0.0.coordinate.clLocationCoordinate, $0.1.coordinate.clLocationCoordinate)))
        }.filter { $0.distance < distance }.sorted(by: { $0.distance < $1.distance }).first.map { $0.segment }
    }
    
    func interpolatedPoint(for coord: Coordinate) -> CoordinateWithElevation? {
        guard let segment = self.segmentWithElevation(closestTo: coord.clLocationCoordinate, maxDistance: epsilon) else { return nil }
        let segmentCL = (segment.0.coordinate.clLocationCoordinate, segment.1.coordinate.clLocationCoordinate)
        let amount = coord.clLocationCoordinate.amount(segment: segmentCL)
        let coord = coord.clLocationCoordinate.closestPointOn(segment: segmentCL)
        let deltaElevation = segment.1.elevation - segment.0.elevation
        return CoordinateWithElevation(coordinate: Coordinate(coord), elevation: segment.0.elevation + amount * deltaElevation)
        
    }

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
        let indices: Array<Int>
        if reversed {
            indices = (Array(0..<coordinates.endIndex) + Array(0..<index)).reversed()
        } else {
            indices = Array(index..<coordinates.endIndex) + Array(0..<index)
        }
        for x in indices.dropFirst() {
            let coord = coordinates[x].coordinate
            defer { previous = coord }
            distanceToStartVertex += CLLocation(coord.clLocationCoordinate).distance(from: CLLocation(previous.clLocationCoordinate))
            if vertices.contains(coord) {
                return (coord, distanceToStartVertex)

            }
        }
        return nil
    }
    
    func vertexBefore(coordinate: Coordinate, at index: Int, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        return vertexHelper(coordinate: coordinate, at: index, graph: graph, reversed: true)
    }
    
    func vertexAfter(coordinate: Coordinate, at index: Int, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        return vertexHelper(coordinate: coordinate, at: index, graph: graph, reversed: false)
    }
    
    func vertexBefore(coordinate: Coordinate, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        guard let index = coordinates.index(where: { $0.coordinate == coordinate }) else { return nil }
        return vertexHelper(coordinate: coordinate, at: index, graph: graph, reversed: true)
    }
    
    func vertexAfter(coordinate: Coordinate, graph: Graph) -> (Coordinate, CLLocationDistance)? {
        guard let index = coordinates.index(where: { $0.coordinate == coordinate }) else { return nil }
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

struct Graph: Codable, Equatable {
    static func ==(lhs: Graph, rhs: Graph) -> Bool {
        return lhs.items.keys == rhs.items.keys // todo hack hack
    }
    
    private(set) var items: [Coordinate:[Entry]] = [:]
    
    struct Entry: Codable, Equatable {
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
        return items[from] ?? []
    }
}

extension Graph {
    /// Dijkstra's shortest path.
    func shortestPath(from source: Coordinate, to target: Coordinate) -> (path: [Entry], distance: CLLocationDistance)? {
        var known: Set<Coordinate> = []
        var distances: [Coordinate:(previousEdge: (Coordinate, Entry)?, distance: CLLocationDistance)] = [source: (nil, 0)]
        var queue = SortedArray<(Coordinate, distance: CLLocationDistance)>(unsorted: [(source, 0)] , isAscending: { $0.distance > $1.distance })

        
        while let (coord, _) = queue.popLast() {
            if coord == target {
                break
            }

            guard !known.contains(coord) else { continue }
            let distVNext = distances[coord]!.distance
            
            for edge in edges(from: coord) {
                let existing = distances[edge.destination]
                let existingDistance = existing?.distance ?? .greatestFiniteMagnitude
                let tentativeDistance = distVNext + edge.distance
                if !known.contains(edge.destination) && tentativeDistance < existingDistance {
                    distances[edge.destination] = (previousEdge: (coord, edge), distance: tentativeDistance)
                    if let i = queue.index(where: { $0.0 == edge.destination }) {
                        queue.mutate(at: i, { $0.1 = tentativeDistance })
                    } else {
                        queue.insert((edge.destination, tentativeDistance))
                    }
                    
                }
            }
            known.insert(coord)
        }
        guard let (_, distance) = distances[target] else { return nil }
        
        var path: [Entry] = []
        var current = target
        while case let ((previousCoord, edge)?, _)? = distances[current] {
            path.append(edge)
            current = previousCoord
        }
        return (path: path.reversed(), distance: distance)
    }
}

extension Track {
    var boundingBox: MKMapRect {
        return polygon.boundingMapRect
    }
}

extension MKMapRect {
    func intersects(_ other: MKMapRect) -> Bool {
        return MKMapRectIntersectsRect(self, other)
    }
    
    func contains(_ point: MKMapPoint) -> Bool {
        return MKMapRectContainsPoint(self, point)
    }
}

let epsilon: Double = 3

func buildGraph(tracks: [Track], url: URL, progress: @escaping (Float) -> ()) -> Graph {
    var graph = Graph()
    let maxDistance: Double = 25
    
    let boundingBoxes = Dictionary(tracks.map {
        ($0.name, $0.boundingBox)
    }, uniquingKeysWith: { $1 })
    
    
    // todo we can parallelize this
    for (trackIndex, t) in tracks.enumerated() {
        progress(Float(trackIndex) / Float(tracks.count))
        let kdPoints = t.kdPoints
        let boundingBox = boundingBoxes[t.name]!
        
        let neighbors = tracks.filter { $0.name != t.name && boundingBox.intersects(boundingBoxes[$0.name]!) }
        
        let joinedPoints: [(TrackPoint, overlaps: [(Box<Track>, Segment)])] = kdPoints.map { p in
            let pointNeighbors = neighbors.compactMap { neighbor in
                neighbor.segment(closeTo: p.point.coordinate, maxDistance: maxDistance).map { (Box(neighbor), $0) }
            }
            return (p, pointNeighbors)
        }
        
        let grouped: [[(TrackPoint, overlaps: [(Box<Track>, Segment)])]] = joinedPoints.group(by: { $0.overlaps.map { $0.0 }  == $1.overlaps.map { $0.0 } })
        
        var previous: Coordinate? = Coordinate(grouped.last!.last!.0.point.coordinate) // by starting with the last as the previous, we create a full loop
        for group in grouped {
            let first = group[0]
            
            let from = first.0.point
            let to = group.last!.0.point
            
            if let p = previous {
                let d = p.clLocationCoordinate.squaredDistanceApproximation(to: from.coordinate).squareRoot()
                graph.add(from: p, Graph.Entry(destination: Coordinate(from.coordinate), distance: d, trackName: t.name))
            }
            
            previous = Coordinate(to.coordinate)
            
            let distance = group.map { $0.0.point }.distance
            graph.add(from: Coordinate(from.coordinate), Graph.Entry(destination: Coordinate(to.coordinate), distance: distance, trackName: t.name))
            
            // todo remove the duplication below
            for o in group[0].overlaps {
                let segment = o.1
                let closest = from.coordinate.closestPointOn(segment: segment)
                let distance = from.coordinate.squaredDistance(to: segment).squareRoot()
                
                graph.add(from: Coordinate(from.coordinate), Graph.Entry(destination: Coordinate(closest), distance: distance, trackName: "Close"))
                graph.add(from: Coordinate(closest), Graph.Entry(destination: Coordinate(segment.0), distance: closest.squaredDistanceApproximation(to: segment.0).squareRoot(), trackName: "Close"))
                graph.add(from: Coordinate(closest), Graph.Entry(destination: Coordinate(segment.1), distance: closest.squaredDistanceApproximation(to: segment.0).squareRoot(), trackName: "Close"))
            }
            
            for o in group.last!.overlaps {
                let segment = o.1
                let closest = to.coordinate.closestPointOn(segment: segment)
                let distance = to.coordinate.squaredDistance(to: segment).squareRoot()
                
                graph.add(from: Coordinate(to.coordinate), Graph.Entry(destination: Coordinate(closest), distance: distance, trackName: "Close"))
                graph.add(from: Coordinate(closest), Graph.Entry(destination: Coordinate(segment.0), distance: closest.squaredDistanceApproximation(to: segment.0).squareRoot(), trackName: "Close"))
                graph.add(from: Coordinate(closest), Graph.Entry(destination: Coordinate(segment.1), distance: closest.squaredDistanceApproximation(to: segment.0).squareRoot(), trackName: "Close"))
            }
            
        }
    }
    
    let json = JSONEncoder()
    let result = try! json.encode(graph)
    try! result.write(to: url)
    
    print("Built graph \(url)")
    
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



extension TrackPoint {    
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
