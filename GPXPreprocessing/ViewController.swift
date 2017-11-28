//
//  ViewController.swift
//  GPXPreprocessing
//
//  Created by Chris Eidhof on 12.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Cocoa
import MapKit
import Incremental_Mac
import KDTree

struct StoredState: Equatable, Codable {
    var annotationsVisible: Bool = false
    var satellite: Bool = false
    var showConfiguration: Bool = false
    
    static func ==(lhs: StoredState, rhs: StoredState) -> Bool {
        return lhs.annotationsVisible == rhs.annotationsVisible && lhs.satellite == rhs.satellite && lhs.showConfiguration == rhs.showConfiguration
    }
}

struct CoordinateAndTrack: Equatable, Codable { // tuples aren't codable
    static func ==(lhs: CoordinateAndTrack, rhs: CoordinateAndTrack) -> Bool {
        return lhs.coordinateIndex == rhs.coordinateIndex && lhs.track == rhs.track
    }
    
    let coordinateIndex: Int
    let track: Track
    
    var coordinate: Coordinate {
        return track.coordinates[coordinateIndex].coordinate
    }
}

struct Route: Equatable, Codable {
    static func ==(lhs: Route, rhs: Route) -> Bool {
        return lhs.points == rhs.points
    }
    
    var points: [CoordinateAndTrack]
}


struct DisplayState: Equatable, Codable {
    var tracks: [Track]
    var tmpPoints: [Coordinate] = []
    var graph: Graph? = nil
    var loading: Bool { return tracks.isEmpty }
    
    var selection: Track? {
        didSet {
            trackPosition = nil
        }
    }
    
    var hasSelection: Bool {
        return selection != nil
    }
    
    var firstPoint: Coordinate?
    
    var trackPosition: CGFloat? // 0...1
    
    init(tracks: [Track]) {
        selection = nil
        trackPosition = nil
        self.tracks = tracks
    }
    
    var route: Route? = nil
    
    var draggedLocation: (Double, CLLocation)? {
        guard let track = selection,
            let location = trackPosition else { return nil }
        let distance = Double(location) * track.distance
        guard let point = track.point(at: distance) else { return nil }
        return (distance: distance, location: point)
    }
    
    static func ==(lhs: DisplayState, rhs: DisplayState) -> Bool {
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.firstPoint == rhs.firstPoint && lhs.graph == rhs.graph && lhs.route == rhs.route && lhs.tmpPoints == rhs.tmpPoints
    }
}

func polygonRenderer(polygon: MKPolygon, strokeColor: I<LColor>, fillColor: I<LColor?>, alpha: I<CGFloat>, lineWidth: I<CGFloat>) -> IBox<MKPolygonRenderer> {
    let renderer = MKPolygonRenderer(polygon: polygon)
    let box = IBox(renderer)
    box.bind(strokeColor, to: \.strokeColor)
    box.bind(alpha, to : \.alpha)
    box.bind(lineWidth, to: \.lineWidth)
    box.bind(fillColor, to: \.fillColor)
    return box
}

func annotation(location: I<CLLocationCoordinate2D>) -> IBox<MKPointAnnotation> {
    let result = IBox(MKPointAnnotation())
    result.bind(location, to: \.coordinate)
    return result
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension Sequence {
    var cycled: AnyIterator<Element> {
        var current = makeIterator()
        return AnyIterator {
            guard let result = current.next() else {
                current = self.makeIterator()
                return current.next()
            }
            return result
        }

    }
}

typealias Segment = (CLLocationCoordinate2D, CLLocationCoordinate2D)

extension CLLocationCoordinate2D {
    // stolen from https://github.com/mhawkins/GCRDPProcessor/blob/master/GCRDPProcessor/GCRDPProcessor.m
    func closestPointOn(segment: Segment) -> CLLocationCoordinate2D {
        let deltaLat = segment.1.latitude - segment.0.latitude
        let deltaLon = segment.1.longitude - segment.0.longitude
        
        var u = CLLocationDegrees(
            (latitude - segment.0.latitude) *
                (segment.1.latitude - segment.0.latitude) +
                (longitude - segment.0.longitude) *
                (segment.1.longitude - segment.0.longitude)
            ) / (pow(deltaLat, 2) + pow(deltaLon, 2))
        
        
        u = max(0, min(u,1)) // clamp to 0...1
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


/// Returns a function that you can call to set the visible map rect
func addMapView(persistent: Input<StoredState>, state: Input<DisplayState>, rootView: IBox<NSView>) -> ((MKMapRect) -> ()) {
    var polygonToTrack: [MKPolygon:Track] = [:]
    let darkMode = persistent[\.satellite]
    
    func buildRenderer(_ polygon: MKPolygon) -> IBox<MKPolygonRenderer> {
        let track = polygonToTrack[polygon]!
        let isSelected = state.i[\.selection].map { $0 == track }
        let shouldHighlight = !state.i[\.hasSelection] || isSelected
        let lineColor = polygonToTrack[polygon]!.color.uiColor
        let fillColor = if_(isSelected, then: lineColor.withAlphaComponent(0.2), else: lineColor.withAlphaComponent(0.1))
        return polygonRenderer(polygon: polygon,
                               strokeColor: I(constant: lineColor),
                               fillColor: fillColor.map { $0 },
                               alpha: if_(shouldHighlight, then: I(constant: 1.0), else: if_(darkMode, then: 0.7, else: 1.0)),
                               lineWidth: if_(shouldHighlight, then: I(constant: 3.0), else: if_(darkMode, then: 1.0, else: 1.0)))
    }
    
    let mapView: IBox<MKMapView> = newMapView()
    rootView.addSubview(mapView, constraints: sizeToParent())
    
    
    var color = NSColor.white
//    var colors = cycle(elements: [NSColor.white]) //, .black, .blue, .brown, .cyan, .darkGray, .green, .magenta, .orange])
    // MapView
    mapView.delegate = MapViewDelegate(rendererForOverlay: { [unowned mapView] mapView_, overlay in
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            mapView.disposables.append(renderer)
            return renderer.unbox
        } else if let l = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: l)
            renderer.lineWidth = 5
            renderer.strokeColor = color
            return renderer
        }
        return MKOverlayRenderer()
        }, viewForAnnotation: { (mapView, annotation) -> MKAnnotationView? in
            guard annotation is MKPointAnnotation else { return nil }
            if POI.all.contains(where: { $0.location == annotation.coordinate }) {
                let result: MKAnnotationView
                result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
                result.canShowCallout = true
                return result
            } else {
                let result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
                result.pinTintColor = annotation.title! == "x" ? .red : .black
                result.canShowCallout = true
                return result
            }
    }, regionDidChangeAnimated: { [unowned mapView] _ in
//        print(mapView.unbox.region)
    }, didSelectAnnotation: { mapView, annotationView in
        print(annotationView.annotation!.title)
    })
    
    mapView.bind(annotations: state.i.map { $0.tmpPoints.map { MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "" )} })
    
//    mapView.bind(annotations: state.i.map {
//        if $0.tmpPoints.count == 3 {
//
//        }
//    })

    mapView.disposables.append(state.i.map { $0.tracks }.observe { [unowned mapView] in
        mapView.unbox.removeOverlays(mapView.unbox.overlays)
        $0.forEach { track in
            let polygon = track.polygon
            polygonToTrack[polygon] = track
            mapView.unbox.add(polygon)
        }
    })
    
    /*
    mapView.addGestureRecognizer(clickGestureRecognizer { [unowned mapView] sender in
        let point = sender.location(in: mapView.unbox)
        let coordinate = mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox)
        state.change {
            if $0.tmpPoints.count == 4 {
                $0.tmpPoints = []
            }
            $0.tmpPoints.append(Coordinate(coordinate))
            if $0.tmpPoints.count == 3 {
                let segment = ($0.tmpPoints[0].clLocationCoordinate, $0.tmpPoints[1].clLocationCoordinate)
                let dest = $0.tmpPoints[2].clLocationCoordinate
                $0.tmpPoints.append(Coordinate(dest.closestPointOn(segment: segment)))
                print(dest.squaredDistance(to: segment).squareRoot())
            }
        }
    })
 */
    mapView.bind(persistent.i.map { $0.satellite ? .hybrid : .standard }, to: \.mapType)
    
//    let allPoints: I<[(CLLocationCoordinate2D, String)]> = state.i.map { $0.tracks.flatMap { t in t.coordinates.map { ($0.coordinate.clLocationCoordinate, t.name) }}}
//    mapView.bind(annotations: allPoints.map { $0.map { MKPointAnnotation(coordinate: $0.0, title: $0.1)}})
    
    return { mapView.unbox.setVisibleMapRect($0, animated: true) }
}

extension CGRect {
    init(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) {
        let x = centerX - width/2
        let y = centerY - height/2
        self = CGRect(x: x, y: y, width: width, height: height)
    }
}


func time<Result>(name: StaticString = #function, line: Int = #line, _ f: () -> Result) -> Result {
    let startTime = DispatchTime.now()
    let result = f()
    let endTime = DispatchTime.now()
    let diff = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000 as Double
    print("\(name) (line \(line)): \(diff) sec")
    return result
}

let epsilon: Double = 3

final class ViewController: NSViewController {
    @IBOutlet var _mapView: MKMapView!
    
    let storedState = Input<StoredState>(StoredState(annotationsVisible: false, satellite: true, showConfiguration: false))
    let state = Input(DisplayState(tracks: []))
    var rootView: IBox<NSView>!
    
    override func viewDidLoad() {
        rootView = IBox(view)
        let setMapRect = addMapView(persistent: storedState, state: state, rootView: rootView)
        setMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)))
        let mapView = self.view.subviews[0] as! MKMapView
        DispatchQueue(label: "async").async {
            let tracks = Array(Track.load()).map { (track: Track) -> Track in
                var copy = track
                let before = copy.coordinates.count
                copy.coordinates = track.coordinates.douglasPeucker(coordinate: { $0.coordinate.clLocationCoordinate }, squaredEpsilonInMeters: epsilon*epsilon)
                print("before: \(before), after: \(copy.coordinates.count)")
                return copy
            }
            
            DispatchQueue.main.async {
                self.state.change {
                    $0.tracks = tracks
                    var rects = $0.tracks.map { $0.polygon.boundingMapRect }
                    let first = rects.removeFirst()
                    let boundingBox = rects.reduce(into: first, { (rect1, rect2) in
                        rect1 = MKMapRectUnion(rect1, rect2)
                    })
                    setMapRect(boundingBox)
                }
            }
            time {
                buildGraphAlt(tracks: tracks, url: graphURL, mapView: mapView)
            }
            let graph = readGraph(url: graphURL)
            DispatchQueue.main.async {
                self.state.change {
                    $0.graph = graph
                }
            }
        }
    }
}

extension KDTreePoint {
    func range(upTo other: Self) -> [(Double,Double)] {
        return (0..<Self.dimensions).map {
            let v1 = kdDimension($0)
            let v2 = other.kdDimension($0)
            return v1 < v2 ? (v1, v2) : (v2, v1)
        }
    }
}

func buildGraphAlt(tracks: [Track], url: URL, mapView: MKMapView) -> Graph {
    var graph = Graph()
    let tree = KDTree(values: tracks.flatMap { $0.kdPoints })
    let epsilonSquared: Double = 25*25
    
    for t in tracks {
        let kdPoints = t.kdPoints
        
        for p in kdPoints {
            var seen: Set<String> = []
            let close = tree.nearestK(20, to: p, where: { $0.track.unbox != p.track.unbox })
            var result: String = ""
            for c in close {
                guard !seen.contains(c.track.unbox.name) else { continue }
                let coordinates = c.track.unbox.coordinates
                let index = coordinates.index { $0.coordinate.clLocationCoordinate == c.point.coordinate }!
                let before = index - 1
                let after = index + 1
                var d1: Double = -1
                var d2: Double = -1
                if let b = coordinates[safe: before] {
                    d1 = p.point.coordinate.squaredDistance(to: (c.point.coordinate, b.coordinate.clLocationCoordinate))
                    if d1 < epsilonSquared {
                        result.append(c.track.unbox.name)
                        seen.insert(c.track.unbox.name)

                        continue
                    }
                } else if let b = coordinates[safe: after] {
                    d2 = p.point.coordinate.squaredDistance(to: (c.point.coordinate, b.coordinate.clLocationCoordinate))
                    if d2 < epsilonSquared {
                        result.append(c.track.unbox.name)
                        seen.insert(c.track.unbox.name)
                        continue
                    }
                }
            }
            DispatchQueue.main.async {
                if result.isEmpty {
                    mapView.addAnnotation(MKPointAnnotation(coordinate: p.point.coordinate, title: "y \(t.name)"))
                } else {
                    mapView.addAnnotation(MKPointAnnotation(coordinate: p.point.coordinate, title: "x"))
                }
            }
            
        }
        
        // step 1: merge the really close points (epsilon*2)
        
//        for (p0,p1) in zip(kdPoints, kdPoints.dropFirst() + [kdPoints[0]]) {
//            let close = tree.nearestK(10, to: p0).filter { $0.track.unbox != p0.track.unbox }.map { ($0, $0.squaredDistance(to: p0)) }.filter { $0.1 < epsilonSquared }
//            print(close)
//            DispatchQueue.main.async {
//
//            }
//
//            let neighbors = tree.elementsIn(p0.range(upTo: p1)).filter {
//                $0.track.unbox != t
//            }
//            print(neighbors)
//        }
//        let joinedPoints: [(TrackPoint, overlaps: [Box<Track>])] = t.kdPoints.enumerated().map { (ix, point) in
//            var seen: [Box<Track>] = []
//            for neighbor in tree.nearestK(10, to: point) {
//                let maxDistance = 20 as Double
//                if neighbor.track != point.track && !seen.contains(neighbor.track) && point.distanceInMeters(to: neighbor) < maxDistance {
//                    seen.append(neighbor.track)
//                }
//            }
//            seen.sort(by: { $0.unbox.name < $1.unbox.name })
//            return (point, overlaps: seen) // this also appends non-overlapping points
//        }
//
//        let grouped: [[(TrackPoint, overlaps: [Box<Track>])]] = joinedPoints.group(by: { $0.overlaps == $1.overlaps })
//        //            .mergeSmallGroupsAlt(maxSize: 1)
//        //            .joined()
//        //            .group(by: { $0.overlaps == $1.overlaps })
//        //        grouped.map { ($0.first!.overlaps.map { $0.unbox.name }, $0.count) }.forEach { print($0) }
//        for segment in grouped {
//            let first = segment[0]
//            let from = first.0.point
//            let to = segment.last!.0.point
//            let distance = segment.map { $0.0.point }.distance
//            for t in segment[0].overlaps {
//                graph.add(from: Coordinate(from.coordinate), Graph.Entry(destination: Coordinate(to.coordinate), distance: distance, trackName: t.unbox.name))
//            }
//
//        }
//        let last = t.coordinates.last!.coordinate
//        let first = t.coordinates[0].coordinate
//        graph.add(from: last, Graph.Entry(destination: first, distance: CLLocation(last.clLocationCoordinate).distance(from: CLLocation(first.clLocationCoordinate)), trackName: t.name))
    }
    
    let json = JSONEncoder()
    let result = try! json.encode(graph)
    try! result.write(to: url)
    
    return graph
}

let graphURL = URL(fileURLWithPath: "/Users/chris/Downloads/graph.json")
