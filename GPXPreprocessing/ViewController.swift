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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.firstPoint == rhs.firstPoint && lhs.graph == rhs.graph && lhs.route == rhs.route
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
                //result.image = NSImage(named: "partner")!
//                result.frame.size = CGSize(width: 32, height: 32)
                
                
                result.canShowCallout = true
                return result
            } else {
                let result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
                result.pinTintColor = .red
//                result.canShowCallout = true
                return result
            }
    }, regionDidChangeAnimated: { [unowned mapView] _ in
//        print(mapView.unbox.region)
    }, didSelectAnnotation: { mapView, annotationView in
        print(annotationView.annotation!.title)
//        if let g = state.i.value.graph {
//            let edges = g.edges(from: Coordinate(annotationView.annotation!.coordinate))
//            for edge in edges {
//                let coordinates = [annotationView.annotation!.coordinate, edge.destination.clLocationCoordinate]
//                mapView.add(MKPolyline(coordinates: coordinates, count: coordinates.count))
//            }
//            print(edges)
//        }
//        for entry in entries {
//            var points = [coord, entry.destination.clLocationCoordinate]
//            let line = MKPolyline(coordinates: points, count: points.count)
//            mapView.add(line)
//            print(entry)
//        }
    })
    mapView.disposables.append(state.i.map { $0.tracks }.observe { [unowned mapView] in
        mapView.unbox.removeOverlays(mapView.unbox.overlays)
        $0.forEach { track in
            let polygon = track.polygon
            polygonToTrack[polygon] = track
            mapView.unbox.add(polygon)
        }
    })
    
    mapView.bind(annotations: POI.all.map { poi in MKPointAnnotation(coordinate: poi.location, title: poi.name) }, visible: persistent[\.annotationsVisible])
    
//    let vertices = state.i.map { $0.graph?.vertices ?? [] }
//    mapView.observe(value: vertices, onChange: { mv, v in
//        mv.addAnnotations(v.map {
//            MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "")
//        })
//    })
    
//    mapView.bind(annotations: vertices.map {  }, visible: I(constant: true))
    
//    mapView.addGestureRecognizer(clickGestureRecognizer { [unowned mapView] sender in
//    }
    
    mapView.disposables.append(state.i.map { $0.route }.observe { [unowned mapView] route in
        mapView.unbox.removeAnnotations(mapView.unbox.annotations.filter { $0 is MKPointAnnotation })
        mapView.unbox.removeOverlays(mapView.unbox.overlays.filter { $0 is MKPolyline })

        guard let r = route, var graph = state.i.value.graph, !r.points.isEmpty else { return }
        
        var points = r.points
        var previous = points.removeFirst()
        if let previousVertex = previous.track.vertexAfter(coordinate: previous.coordinate, at: previous.coordinateIndex, graph: graph) {
            graph.add(from: previous.coordinate, Graph.Entry(destination: previousVertex.0, distance: previousVertex.1, trackName: previous.track.name))
        } else {
            print("couldn't find after")
        }
        
        if let nextVertex = previous.track.vertexBefore(coordinate: previous.coordinate, at: previous.coordinateIndex, graph: graph) {
            graph.add(from: previous.coordinate, Graph.Entry(destination: nextVertex.0, distance: nextVertex.1, trackName: previous.track.name))
        } else {
            print("couldn't find before")
        }
        
        
        mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: previous.coordinate.clLocationCoordinate, title: ""))
        var totalDistance: CLLocationDistance = 0
        
        while !points.isEmpty {
            
            let next = points.removeFirst()
            if let vertexAfter = next.track.vertexAfter(coordinate: next.coordinate, at: next.coordinateIndex, graph: graph) {
                graph.add(from: vertexAfter.0, Graph.Entry(destination: next.coordinate, distance: vertexAfter.1, trackName: next.track.name))
                print("found vertex after: \(vertexAfter.1)")
                mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: vertexAfter.0.clLocationCoordinate, title: "after"))
            }
            
            if let vertexBefore = next.track.vertexBefore(coordinate: next.coordinate, at: next.coordinateIndex, graph: graph) {
                graph.add(from: vertexBefore.0, Graph.Entry(destination: next.coordinate, distance: vertexBefore.1, trackName: next.track.name))
                print("found vertex before")
                mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: vertexBefore.0.clLocationCoordinate, title: "before"))
            }
            
            
            if let path = graph.shortestPath(from: previous.coordinate, to: next.coordinate) {
                let coords: [CLLocationCoordinate2D] = path.path.reduce(into: [previous.coordinate.clLocationCoordinate], { result, el in
                    result.append(el.destination.clLocationCoordinate)
                })  + [next.coordinate.clLocationCoordinate]
                color = .black
                let line = MKPolyline(coordinates: coords, count: coords.count)
                mapView.unbox.add(line)
                print("found it: \(path.distance)")
                totalDistance += path.distance
            } else {
                print("not found")
                print(graph.vertices.contains(previous.coordinate))
                print(graph.vertices.contains(next.coordinate))
            }
            mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: next.coordinate.clLocationCoordinate, title: ""))
            previous = next
        }
        print("total distance: \(totalDistance)")
    })
    
    mapView.addGestureRecognizer(clickGestureRecognizer { [unowned mapView] sender in

        let point = sender.location(in: mapView.unbox)
        let coordinate = mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(coordinate)
        let possibilities = polygonToTrack.filter { (polygon, track) in
            let renderer = mapView.unbox.renderer(for: polygon) as! MKPolygonRenderer
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point) // todo we should not only do contains, but check if the point is close to the track. now we can only click inside.
            // we could make a maprect out of mapPoint, and then check for intersection
        }

        let region = MKCoordinateRegionMakeWithDistance(mapView.unbox.centerCoordinate, 1, 1)
        let rect = mapView.unbox.convertRegion(region, toRectTo: mapView.unbox)
        let meterPerPixel = Double(1/rect.width)
        let tresholdPixels: Double = 10
        let treshold = (meterPerPixel*tresholdPixels)*(meterPerPixel*tresholdPixels)

        func findPoint() -> (Track, Int, CoordinateWithElevation)? {
            for p in possibilities {
                for (index, point) in p.value.coordinates.enumerated() {
                    let squaredDistance = point.coordinate.clLocationCoordinate.squaredDistanceApproximation(to: coordinate)
                    if  squaredDistance < treshold {
                        return (p.value, index, point) // todo don't return the first matchh but the best match!
                    }
                }
            }
            return nil
        }

        if let graph = state.i.value.graph {
            if let (track, ix, coord) = findPoint() {
                state.change {
                    let x = CoordinateAndTrack(coordinateIndex: ix, track: track)
                    if $0.route == nil { $0.route = Route(points: []) }
                    $0.route!.points.append(x)
                }
//                mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: coord.coordinate.clLocationCoordinate, title: "POINT"))
//                if let start = startVertex {
//                    mapView.unbox.addAnnotation(MKPointAnnotation(coordinate: start.clLocationCoordinate, title: "START VERTEX"))
//                }
            }
        }

//        print(possibilities.count)
    })
    /*
    mapView.addGestureRecognizer(clickGestureRecognizer { [unowned mapView] sender in
        let point = sender.location(in: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox))
        let possibilities = polygonToTrack.filter { (polygon, track) in
            let renderer = mapView.unbox.renderer(for: polygon) as! MKPolygonRenderer
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point)
        }
        
        // in case of multiple matches, toggle between the selections, and start out with the smallest route
        if let s = state.i[\.selection].value ?? nil, possibilities.count > 1 && possibilities.values.contains(s) {
            state.change {
                $0.selection = possibilities.lazy.sorted { $0.key.pointCount < $1.key.pointCount }.first(where: { $0.value != s }).map { $0.value }
            }
        } else {
            state.change { $0.selection = possibilities.first?.value }
        }
        
    })
 */
    mapView.bind(persistent.i.map { $0.satellite ? .hybrid : .standard }, to: \.mapType)
    
    let draggedLocation = state.i.map { $0.draggedLocation }
    
    // Dragged Point Annotation
    let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map {
        $0?.1.coordinate ?? CLLocationCoordinate2D()
    }
    let draggedPointAnnotation = annotation(location: draggedPoint)
    mapView.unbox.addAnnotation(draggedPointAnnotation.unbox)
    
    // Center the map location on position dragging
    mapView.disposables.append(draggedLocation.observe { [unowned mapView] x in
        guard let (_, location) = x else { return }
        // todo subtract the height of the trackInfo box (if selected)
        if !mapView.unbox.annotations(in: mapView.unbox.visibleMapRect).contains(draggedPointAnnotation.unbox) {
            mapView.unbox.setCenter(location.coordinate, animated: true)
        }
    })
    
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
            let tracks = Array(Track.load()) //.filter { $0.color == .orange || $0.color == .blue }
            print(tracks[0].coordinates[0].coordinate.clLocationCoordinate)
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
                buildGraph(tracks: tracks, url: graphURL)
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


let graphURL = URL(fileURLWithPath: "/Users/chris/Downloads/graph.json")
