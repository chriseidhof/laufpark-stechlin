//
//  State.swift
//  Laufpark
//
//  Created by Chris Eidhof on 02.12.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import CoreLocation

struct StoredState: Equatable, Codable {
    var annotationsVisible: Bool = false
    var satellite: Bool = false
    var showConfiguration: Bool = false
    
    static func ==(lhs: StoredState, rhs: StoredState) -> Bool {
        return lhs.annotationsVisible == rhs.annotationsVisible && lhs.satellite == rhs.satellite && lhs.showConfiguration == rhs.showConfiguration
    }
}

struct Path: Equatable, Codable {
    let entries: [Graph.Entry]
    let distance: CLLocationDistance
    
    static func ==(lhs: Path, rhs: Path) -> Bool {
        return lhs.entries == rhs.entries && lhs.distance == rhs.distance
    }
}

struct CoordinateAndTrack: Equatable, Codable { // tuples aren't codable
    static func ==(lhs: CoordinateAndTrack, rhs: CoordinateAndTrack) -> Bool {
        return lhs.coordinate == rhs.coordinate && lhs.track == rhs.track && lhs.pathFromPrevious == rhs.pathFromPrevious
    }
    
    let coordinate: Coordinate
    let track: Track
    var pathFromPrevious: Path?
}


extension DisplayState {
    mutating func removeLastWayPoint() {
        if let r = route, r.wayPoints.count > 1 {
            route!.removeLastWaypoint()
        } else {
            route = nil
        }
    }
    
    mutating func addWayPoint(track: Track, coordinate c2d: CLLocationCoordinate2D, segment: Segment) {
        guard graph != nil else { return }
        
        let coordinate = Coordinate(c2d)
        assert(c2d.squaredDistance(to: segment).squareRoot() < 0.1)
        
        let segment0 = Coordinate(segment.0)
        let segment1 = Coordinate(segment.1)
        
        func add(from: Coordinate, _ entry: Graph.Entry) {
            graph!.add(from: from, entry)
        }
        add(from: coordinate, Graph.Entry(destination: segment0, distance: segment.0.squaredDistanceApproximation(to: c2d).squareRoot(), trackName: track.name))
        add(from: coordinate, Graph.Entry(destination: segment1, distance: segment.1.squaredDistanceApproximation(to: c2d).squareRoot(), trackName: track.name))
        
        if let vertex = track.vertexAfter(coordinate: segment0, graph: graph!) {
            add(from: segment0, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            print("error")
        }
        if let vertex = track.vertexBefore(coordinate: segment0, graph: graph!) {
            add(from: segment0, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            print("error")
        }
        
        if let vertex = track.vertexAfter(coordinate: segment1, graph: graph!) {
            add(from: segment1, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            print("error")
        }
        if let vertex = track.vertexBefore(coordinate: segment1, graph: graph!) {
            add(from: segment1, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            print("error")
        }
        
        
        if route == nil {
            route = Route(track: track, coordinate: coordinate)
        } else {
            route!.add(coordinate: coordinate, inTrack: track, graph: graph!)
        }
    }
}

struct DisplayState: Equatable, Codable {
    var tracks: [Track]
    var loading: Bool { return tracks.isEmpty }
    
    var routing: Bool = false {
        didSet {
            if routing {
                selection = nil
            } else {
                route = nil
            }
        }
    }
    var route: Route?
    
    var selection: Track? {
        didSet {
            trackPosition = nil
        }
    }
    
    var graph: Graph?
    var graphBuildingProgress: Float = 0
    
    var hasSelection: Bool {
        return routing == false && selection != nil
    }
    
    var trackPosition: CGFloat? // 0...1
    
    init(tracks: [Track]) {
        selection = nil
        trackPosition = nil
        self.tracks = tracks
    }
    
    var draggedLocation: (Double, CLLocation)? {
        guard let track = selection,
            let location = trackPosition else { return nil }
        let distance = Double(location) * track.distance
        guard let point = track.point(at: distance) else { return nil }
        return (distance: distance, location: point)
    }
    
    static func ==(lhs: DisplayState, rhs: DisplayState) -> Bool {
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.graph == rhs.graph && lhs.routing == rhs.routing && lhs.route == rhs.route && lhs.graphBuildingProgress == rhs.graphBuildingProgress
    }
}
