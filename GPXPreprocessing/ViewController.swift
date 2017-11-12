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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks
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

func cycle<A>(elements: [A]) -> AnyIterator<A> {
    var i = 0
    return AnyIterator {
        defer { i += 1 }
        return elements[i % elements.count]
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
    
    
    var colors = cycle(elements: [NSColor.white]) //, .black, .blue, .brown, .cyan, .darkGray, .green, .magenta, .orange])
    // MapView
    mapView.delegate = MapViewDelegate(rendererForOverlay: { [unowned mapView] mapView_, overlay in
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            mapView.disposables.append(renderer)
            return renderer.unbox
        } else if let l = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: l)
            renderer.lineWidth = 5
            renderer.strokeColor = colors.next()!
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
        guard let coord = annotationView.annotation?.coordinate,
            let entries = state.i.value.graph?.items[Coordinate(coord)] else { return }
        
        for entry in entries {
            var points = [coord, entry.destination.clLocationCoordinate]
            let line = MKPolyline(coordinates: points, count: points.count)
            mapView.add(line)
            print(entry)
        }
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
    
    let vertices = state.i.map { $0.graph?.vertices ?? [] }
    mapView.observe(value: vertices, onChange: { mv, v in
        mv.addAnnotations(v.map {
            MKPointAnnotation(coordinate: $0.clLocationCoordinate, title: "")
        })
    })
    
//    mapView.bind(annotations: vertices.map {  }, visible: I(constant: true))
    
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
            let tracks = Array(Track.load())
            
            DispatchQueue.main.async {
                self.state.change {
                    $0.tracks = tracks
//                    $0.selection = tracks[1]
                    var rects = $0.tracks.map { $0.polygon.boundingMapRect }
                    let first = rects.removeFirst()
                    let boundingBox = rects.reduce(into: first, { (rect1, rect2) in
                        rect1 = MKMapRectUnion(rect1, rect2)
                    })
                    setMapRect(boundingBox)
                    $0.graph = readGraph()
                    
                }
            }
            //buildGraph(tracks: tracks, mapView: mapView)
//            let graph = readGraph()
//            print(graph)
            
        }
    }
}


let graphURL = URL(fileURLWithPath: "/Users/chris/Downloads/graph.json")

func readGraph() -> Graph? {
    let decoder = JSONDecoder()
    guard let data = try? Data(contentsOf: graphURL) else { return nil }
    return try? decoder.decode(Graph.self, from: data)
}

extension Array where Element == [(TrackPoint, overlaps: [Box<Track>])] {
    func mergeSmallGroups() -> [[(TrackPoint, [Box<Track>])]] {
        var result: Array = []
        for group in self {
            if !result.isEmpty && group.count < 10 {
                result[result.endIndex-1].append(contentsOf: group)
            } else {
                result.append(group)
            }
        }
        return result
    }
}


func buildGraph(tracks: [Track], mapView: MKMapView?) {
    var graph = Graph()
    let tree = KDTree(values: tracks.flatMap { $0.kdPoints })
    
    for t in tracks {
        let joinedPoints: [(TrackPoint, overlaps: [Box<Track>])] = t.kdPoints.map { point in
            var seen: [Box<Track>] = []
            for neighbor in tree.nearestK(10, to: point, where: { neighbor in
                neighbor.track != point.track
            }) {
                if !seen.contains(neighbor.track) {
                    if point.squaredDistance(to: neighbor) > 30 { break }
                    seen.append(neighbor.track)
                }
            }
            seen.sort(by: { $0.unbox.name < $1.unbox.name })
            return (point, overlaps: seen) // this also appends non-overlapping points
        }
        
        let grouped: [[(TrackPoint, overlaps: [Box<Track>])]] = joinedPoints.group(by: { $0.overlaps == $1.overlaps })
            .mergeSmallGroups()
        print(t.name)
        grouped.forEach {
            print($0[0].overlaps.map { $0.unbox.name }, $0.count)
        }
        print("---")
        
        for segment in grouped {
            let first = segment[0]
            let from = first.0.point
            let to = segment.last!.0.point
            let distance = segment.map { $0.0.point }.distance
            graph.add(from: Coordinate(from.coordinate), Graph.Entry(destination: Coordinate(to.coordinate), distance: distance, trackName: first.0.track.unbox.name))
        }
        
        
        //print(result.map { $0.count })
        
        
        DispatchQueue.main.async {
            guard let mapView = mapView else { return }
            //                 the overlapping lines
            let lines = grouped.map { $0.map {$0.0 } }.map { (r: [TrackPoint]) -> MKPolyline in
                let arr = r.map { $0.point.coordinate }
                return MKPolyline(coordinates: arr, count: arr.count)
            }
            mapView.addOverlays(lines)
            for segment in grouped {
                let first = segment[0]
                let title = ([first.0.track.unbox.name] + first.overlaps.map { $0.unbox.name }).joined(separator: ", ")
                let from = first.0.point
                let to = segment.last!.0.point
                let vertices = [from.coordinate, to.coordinate]
                mapView.addAnnotations(vertices.map { MKPointAnnotation.init(coordinate: $0, title: title) } )
                
            }
        }
    }
    
    print("Done")
    
    let json = JSONEncoder()
    let result = try! json.encode(graph)
    try! result.write(to: graphURL)
}

struct Graph: Codable {
    private(set) var items: [Coordinate:[Entry]] = [:]

    struct Entry: Codable {
        let destination: Coordinate
        let distance: CLLocationDistance
        let trackName: String
    }

    mutating func add(from: Coordinate, _ entry: Entry) {
        items[from, default: []].append(entry)
    }
    
    var vertices: [Coordinate] { return Array(items.keys) }
}

extension Track {
    var kdPoints: [TrackPoint] {
        let box = Box(self)
        return coordinates.map { coordAndEle in
            TrackPoint(track: box, point: CLLocation(coordAndEle.coordinate.clLocationCoordinate))
        }
    }
}

struct TrackPoint {
    let track: Box<Track>
    let point: CLLocation
}

extension TrackPoint: KDTreePoint {
    static let dimensions = 2
    
    func kdDimension(_ dimension: Int) -> Double {
        return dimension == 0 ? point.coordinate.latitude : point.coordinate.longitude
    }
    
    func squaredDistance(to otherPoint: TrackPoint) -> Double {
        return point.distance(from: otherPoint.point)
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
