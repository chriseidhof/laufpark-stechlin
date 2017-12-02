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

struct Route: Equatable, Codable {
    static func ==(lhs: Route, rhs: Route) -> Bool {
        return lhs.startingPoint == rhs.startingPoint && lhs.points == rhs.points
    }
    
    let startingPoint: CoordinateAndTrack
    var points: [CoordinateAndTrack] = []
    
    init(track: Track, coordinate: Coordinate) {
        startingPoint = CoordinateAndTrack(coordinate: coordinate, track: track, pathFromPrevious: nil)
    }
    
    mutating func add(coordinate: Coordinate, inTrack track: Track, graph: Graph) {
        let previous = points.last ?? startingPoint
        let path = graph.shortestPath(from: previous.coordinate, to: coordinate).map {
            Path(entries: $0.path, distance: $0.distance)
        }
//        assert(path != nil)
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
    
    func allPoints(tracks: [Track]) -> [Coordinate] {
        var result: [Coordinate] = [startingPoint.coordinate]
        for wayPoint in points {
            if let p = wayPoint.pathFromPrevious?.entries {
                for entry in p {
                    if entry.trackName != "Close" {
                        let track = tracks.first { $0.name == entry.trackName }!
                        result += track.points(between: result.last!, and: entry.destination).map { $0.coordinate }
                    }
                    result.append(entry.destination)
                }
            }
            result.append(wayPoint.coordinate)
        }
        return result
    }
    
    mutating func removeLastWaypoint() {
        guard !points.isEmpty else { return }
        points.removeLast()
    }
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


extension DisplayState {
    mutating func addWayPoint(track: Track, coordinate c2d: CLLocationCoordinate2D, segment: Segment) {
        guard graph != nil else { return }
        let coordinate = Coordinate(c2d)
        let d = c2d.squaredDistance(to: segment).squareRoot()
        assert(d < 0.1)
        
        let d0 = segment.0.squaredDistanceApproximation(to: c2d).squareRoot()
        let d1 = segment.1.squaredDistanceApproximation(to: c2d).squareRoot()
        
        let segment0 = Coordinate(segment.0)
        let segment1 = Coordinate(segment.1)
        
        func add(from: Coordinate, _ entry: Graph.Entry) {
            graph!.add(from: from, entry)
        }
        add(from: coordinate, Graph.Entry(destination: segment0, distance: d0, trackName: track.name))
        add(from: coordinate, Graph.Entry(destination: segment1, distance: d1, trackName: track.name))
        
        // todo add a vertex from segment.0 to the graph entry before and after
        
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

var debugMapView: MKMapView!

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
    debugMapView = mapView.unbox
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
            if l.title == "green" {
                renderer.strokeColor = .green
            } else if l.title == "blue" {
                renderer.strokeColor = .blue
            }
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
        state.change {
            if $0.route != nil && $0.route?.wayPoints.last?.clLocationCoordinate == annotationView.annotation?.coordinate {
                $0.route!.removeLastWaypoint()
            }
        }
    })
    
    mapView.bind(annotations: state.i.map { $0.tmpPoints.map { MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "" )} })
    mapView.disposables.append(state.i.map { $0.tracks }.observe { [unowned mapView] in
        mapView.unbox.removeOverlays(mapView.unbox.overlays)
        $0.forEach { track in
            let polygon = track.polygon
            polygonToTrack[polygon] = track
            mapView.unbox.add(polygon)
        }
    })
    
    // Visualize graphs
    /*
    mapView.bind(overlays: state.i.map { $0.graph?.items.flatMap({ entry -> [MKPolyline] in
        entry.value.map {
            let coords = [entry.key.clLocationCoordinate, $0.destination.clLocationCoordinate]
            let result = MKPolyline(coordinates: coords, count: 2)
            result.title = "green"
            return result
        }
    }) ?? [] })
 */
    
    let waypoints: I<[Coordinate]> = state.i.map { $0.route?.wayPoints ?? [] }
    let waypointAnnotations = waypoints.map { coordinates in
        coordinates.map {
            MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "")
        }
    }
    mapView.bind(annotations: waypointAnnotations)
    
    
    
    let allPoints: I<[Coordinate]> = state.i.map { $0.route?.allPoints(tracks: $0.tracks) ?? [] }
    let lines: I<[MKPolyline]> = allPoints.map {
        if $0.isEmpty {
            return []
        } else {
            let coords = $0.map { $0.clLocationCoordinate }
            return [MKPolyline(coordinates: coords, count: coords.count)]
        }
    }
    mapView.bind(overlays: lines)
    
    
    
    mapView.observe(value: state.i.map { $0.route?.distance }, onChange: { print($1) })
    
    func addWaypoint(mapView: IBox<MKMapView>, sender: NSClickGestureRecognizer) {
        let point = sender.location(in: mapView.unbox)
        let coordinate = mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(coordinate)
        
        let region = MKCoordinateRegionMakeWithDistance(mapView.unbox.centerCoordinate, 1, 1)
        let rect = mapView.unbox.convertRegion(region, toRectTo: mapView.unbox)
        let meterPerPixel = Double(1/rect.width)
        let tresholdPixels: Double = 40
        let treshold = meterPerPixel*tresholdPixels
        
        let possibilities = polygonToTrack.filter { (polygon, track) in
            polygon.boundingMapRect.contains(mapPoint)
        }
        
        if let (track, segment) = possibilities.flatMap({ (_,track) in track.segment(closestTo: coordinate, maxDistance: treshold).map { (track, $0) }}).first {
            state.change {
                let pointOnSegment = coordinate.closestPointOn(segment: segment)
                $0.addWayPoint(track: track, coordinate: pointOnSegment, segment: segment)
            }
        }
    }
    
    mapView.addGestureRecognizer(clickGestureRecognizer({ sender in
        addWaypoint(mapView: mapView, sender: sender)
    }))
    

    mapView.bind(persistent.i.map { $0.satellite ? .hybrid : .standard }, to: \.mapType)

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
                buildGraph(tracks: tracks, url: graphURL, mapView: mapView)
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

let graphURL = URL(fileURLWithPath: "/Users/chris/Downloads/graph.json")
