//
//  ViewController.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit
import Incremental
import KDTreeiOS

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
        return lhs.coordinateIndex == rhs.coordinateIndex && lhs.track == rhs.track && lhs.pathFromPrevious == rhs.pathFromPrevious
    }
    
    let coordinateIndex: Int
    let track: Track
    var pathFromPrevious: Path?
    
    var coordinate: Coordinate {
        return track.coordinates[coordinateIndex].coordinate
    }
}

extension DisplayState {
    mutating func addWayPoint(track: Track, atIndex coordinateIndex: Int) {
        guard graph != nil else { return }
        let coordinate = track.coordinates[coordinateIndex].coordinate
        
        if let vertex = track.vertexAfter(coordinate: coordinate, at: coordinateIndex, graph: graph!) {
            graph!.add(from: coordinate, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            fatalError()
        }
        if let vertex = track.vertexBefore(coordinate: coordinate, at: coordinateIndex, graph: graph!) {
            graph!.add(from: coordinate, Graph.Entry(destination: vertex.0, distance: vertex.1, trackName: track.name))
        } else {
            fatalError()
        }
        
        if route == nil {
            route = Route(track: track, coordinateIndex: coordinateIndex)
        } else {
            route!.add(coordinateAt: coordinateIndex, inTrack: track, graph: graph!)
        }
    }
}

struct Route: Equatable, Codable {
    static func ==(lhs: Route, rhs: Route) -> Bool {
        return lhs.startingPoint == rhs.startingPoint && lhs.points == rhs.points
    }
    
    let startingPoint: CoordinateAndTrack
    var points: [CoordinateAndTrack] = []
    
    init(track: Track, coordinateIndex: Int) {
        startingPoint = CoordinateAndTrack(coordinateIndex: coordinateIndex, track: track, pathFromPrevious: nil)
    }
    
    mutating func add(coordinateAt index: Int, inTrack track: Track, graph: Graph) {
        let previous = points.last ?? startingPoint
//        print(graph.edges(from: track.coordinates[index].coordinate))
        let path = graph.shortestPath(from: previous.coordinate, to: track.coordinates[index].coordinate).map {
            Path(entries: $0.path, distance: $0.distance)
        }
        let result = CoordinateAndTrack(coordinateIndex: index, track: track, pathFromPrevious: path)
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
}

struct DisplayState: Equatable, Codable {
    var tracks: [Track]
    var loading: Bool { return tracks.isEmpty }
    
    var routing: Bool = false
    var route: Route?
    
    var selection: Track? {
        didSet {
            trackPosition = nil
        }
    }
    
//    var tree: KDTree<TrackPoint>?
    var graph: Graph?

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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.graph == rhs.graph && lhs.routing == rhs.routing && lhs.route == rhs.route
    }
}

func uiSwitch(initial: I<Bool>, valueChange: @escaping (_ isOn: Bool) -> ()) -> IBox<UISwitch> {
    let view = UISwitch()
    let result = IBox(view)
    result.handle(.valueChanged) { [unowned view] in
        valueChange(view.isOn)
    }
    result.bind(initial, to: \.isOn)
    return result
}

/// Returns a function that you can call to set the visible map rect
func addMapView(persistent: Input<StoredState>, state: Input<DisplayState>, rootView: IBox<UIView>) -> ((MKMapRect) -> ()) {
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

    
    // MapView
    mapView.delegate = MapViewDelegate(rendererForOverlay: { [unowned mapView] mapView_, overlay in
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            mapView.disposables.append(renderer)
            return renderer.unbox
        } else if let line = overlay as? MKPolyline {
            let result = MKPolylineRenderer(polyline: line)
            result.strokeColor = .black
            result.lineWidth = 5
            return result
        }
        return MKOverlayRenderer(overlay: overlay)
        }, viewForAnnotation: { (mapView, annotation) -> MKAnnotationView? in
            guard annotation is MKPointAnnotation else { return nil }
            if POI.all.contains(where: { $0.location == annotation.coordinate }) {
                let result: MKAnnotationView
                
                if #available(iOS 11.0, *) {
                    let ma = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
                    ma.glyphText = "⚑"
                    ma.glyphTintColor = .white
                    ma.markerTintColor = .lightGray
                    ma.titleVisibility = .adaptive
                    result = ma
                } else {
                    result = MKAnnotationView(annotation: annotation, reuseIdentifier: nil)
                    result.image = UIImage(named: "partner")!
                    result.frame.size = CGSize(width: 32, height: 32)
                }
                
                
                result.canShowCallout = true
                return result
            } else {
                let result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
                result.pinTintColor = .red
                return result
            }
    }, regionDidChangeAnimated: { [unowned mapView] _ in
//        print(mapView.unbox.region)
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
    func selectTrack(mapView: IBox<MKMapView>, sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView.unbox)
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
    }
    
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

    func addWaypoint(mapView: IBox<MKMapView>, sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView.unbox)
        let coordinate = mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(coordinate)
        
        let region = MKCoordinateRegionMakeWithDistance(mapView.unbox.centerCoordinate, 1, 1)
        let rect = mapView.unbox.convertRegion(region, toRectTo: mapView.unbox)
        let meterPerPixel = Double(1/rect.width)
        let tresholdPixels: Double = 40
        let treshold = meterPerPixel*tresholdPixels
        
        let possibilities = polygonToTrack.filter { (polygon, track) in
            let renderer = mapView.unbox.renderer(for: polygon) as! MKPolygonRenderer
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point) // todo we should not only do contains, but check if the point is close to the track. now we can only click inside.
            // we could make a maprect out of mapPoint, and then check for intersection
        }
        
        if let x = possibilities.flatMap({ (_,track) in
            track.findPoint(closeTo: coordinate, tresholdInMeters: treshold).map { (track, $0) }
        }).first {
            state.change {
                $0.addWayPoint(track: x.0, atIndex: x.1.index)
            }
        }


    }
    
    
    mapView.addGestureRecognizer(tapGestureRecognizer { [unowned mapView] sender in
        if state.i.value.routing {
            addWaypoint(mapView: mapView, sender: sender)
        } else {
            selectTrack(mapView: mapView, sender: sender)
        }
    })
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

func build(persistent: Input<StoredState>, state: Input<DisplayState>, rootView: IBox<UIView>) -> (MKMapRect) -> () {
    let darkMode = persistent[\.satellite]
    let setMapRect = addMapView(persistent: persistent, state: state, rootView: rootView)
    
    let draggedLocation = state.i.map { $0.draggedLocation }
    
    // Track Info View
    let position: I<CGFloat?> = draggedLocation.map { ($0?.0).map { CGFloat($0) } }
    let elevations = state.i[\.selection].map(eq: { _, _ in false }) { $0?.elevationProfile }
    let points: I<[LineView.Point]> = elevations.map { ele in
        ele.map { profile in
            profile.map { LineView.Point(x: $0.distance, y: $0.elevation) }
        } ?? []
    }
    let (trackInfo, location) = trackInfoView(position: position, points: points, track: state.i[\.selection], darkMode: darkMode)
    trackInfo.disposables.append(location.observe { loc in
        state.change { $0.trackPosition = loc }
    })
    
    func switchWith(label text: String, value: I<Bool>, textColor: I<UIColor>, action: @escaping (Bool) -> ()) -> IBox<UIView> {
        let switchLabel = label(text: I(constant: text), textColor: textColor.map { $0 }, font: I(constant: Stylesheet.smallFont) )
        switchLabel.unbox.textAlignment = .left
        let switch_ = uiSwitch(initial: value, valueChange: action)
        let stack = stackView(arrangedSubviews: [switch_.cast, switchLabel.cast], axis: .vertical)
        return stack.cast
    }
    
    let textColor = darkMode.map { $0 ? UIColor.white : .black }
    
    // Configuration View
    let accomodation = switchWith(label: NSLocalizedString("Unterkünfte", comment: ""), value: persistent[\.annotationsVisible], textColor: textColor, action: { value in persistent.change {
        $0.annotationsVisible = value
        }})
    let satellite = switchWith(label: NSLocalizedString("Satellit", comment: ""), value: persistent[\.satellite], textColor: textColor, action: { value in persistent.change {
        $0.satellite = value
        }})
    
    
    func border() -> IBox<UIView> {
        let _border = UIView()
        _border.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let border = IBox(_border)
        border.bind(state.i[\.selection].map { $0?.color.uiColor ?? .white }, to: \.backgroundColor)
        return border
    }
    
    let inset: CGFloat = 10

    func blurredView<V: UIView>(borderAnchor: @escaping Constraint, child: IBox<V>) -> IBox<UIVisualEffectView> {
        let result = effectView(effect: darkMode.map { UIBlurEffect(style: $0 ? .dark : .light)})
        result.addSubview(border(), path: \.contentView, constraints: [equal(\.leadingAnchor), equal(\.trailingAnchor), borderAnchor])
        result.addSubview(child, path: \.contentView, constraints: [equal(\.leftAnchor, constant: I(constant: -inset)), equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: I(constant: -inset)), equal(\.rightAnchor, constant: I(constant: inset))])        
        return result
    }
    
    
    // Blurred Top View (Configuration)
    let topOffset: I<CGFloat> = if_(persistent.i[\.showConfiguration], then: 0, else: 100 + 1)
    
    let topStackview = stackView(arrangedSubviews: [accomodation, satellite], axis: .horizontal)
    let topView = blurredView(borderAnchor: equal(\.bottomAnchor), child: topStackview)
    
    rootView.addSubview(topView, constraints: [equal(\.leftAnchor), equal(\.rightAnchor), equal(\.topAnchor, constant: topOffset, animation: Stylesheet.dampingAnimation), equalTo(constant: I(constant: 100), \.heightAnchor)])

    topStackview.unbox.alignment = .leading
    topStackview.unbox.distribution = .fillProportionally
    
    
    // Blurred Bottom View (Showing the current track)
    let bottomView = blurredView(borderAnchor: equal(\.topAnchor), child: trackInfo)
    
    let trackInfoHeight: CGFloat = 120
    let blurredViewHeight = trackInfoHeight + 2 * inset
    let bottomOffset: I<CGFloat> = if_(state.i[\.hasSelection], then: 0, else: -(blurredViewHeight + 20))
    trackInfo.unbox.heightAnchor.constraint(equalToConstant: trackInfoHeight).isActive = true
    
    rootView.addSubview(bottomView.map { $0 }, constraints: [equal(\.leftAnchor), equal(\.rightAnchor), equalTo(constant: I(constant: blurredViewHeight), \.heightAnchor), equal(\.bottomAnchor, constant: bottomOffset, animation: Stylesheet.dampingAnimation)])

    // Number View
    let trackNumber = trackNumberView(state.i.map { $0.selection} ?? Track(color: .blue, number: 0, name: "", points: []))
    rootView.addSubview(trackNumber)
    let yConstraint = bottomView.unbox.topAnchor.constraint(equalTo: trackNumber.unbox.centerYAnchor)
    let xConstraint = bottomView.unbox.rightAnchor.constraint(equalTo: trackNumber.unbox.centerXAnchor, constant: 42)
    NSLayoutConstraint.activate([xConstraint,yConstraint])


    
    // Loading Indicator
    let isLoading = state[\.loading] || state[\.routing] && (state.i.map { $0.graph } == nil)
    let loadingIndicator = activityIndicator(style: darkMode.map { $0 ? .gray : .white }, animating: isLoading)
    rootView.addSubview(loadingIndicator, constraints: [equal(\.centerXAnchor), equal(\.centerXAnchor)])
    
    // Toggle Map Button
    let toggleMapButton = button(type: .custom, title: I(constant: "…"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: {
        persistent.change { $0.showConfiguration.toggle() }
    })
    toggleMapButton.unbox.layer.cornerRadius = 3
    rootView.addSubview(toggleMapButton.cast, constraints: [equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: -inset), equal(\.trailingAnchor, 10)])
    
    // Toggle Routing Button
    let toggleRoutingButton = button(type: .custom, title: I(constant: "Route"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: {
        state.change {
            if $0.routing {
                $0.routing = false
                $0.route = nil
            } else {
                $0.routing = true
            }
        }
    })
    toggleRoutingButton.unbox.layer.cornerRadius = 3
    // todo: the layout is a bit of a hack.
    rootView.addSubview(toggleRoutingButton.cast, constraints: [equal(\.safeAreaLayoutGuide.topAnchor, to: \.topAnchor, constant: -(inset + 50)), equal(\.trailingAnchor, 10)])
    
    return setMapRect
}

class ViewController: UIViewController {
    let state: Input<DisplayState>
    let persistentState: Input<StoredState> = persistent(key: "de.laufpark-stechlin.state", initial: StoredState())
    var rootView: IBox<UIView>!

    var disposables: [Any] = []
    var locationManager: CLLocationManager?
    var setMapRect: ((MKMapRect) -> ())?
    
    lazy var graphURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("graph.json")

    init() {
        state = Input(DisplayState(tracks: []))

        super.init(nibName: nil, bundle: nil)
        
//        if let g = readGraph(url: graphURL) {
//            state.change { $0.graph = g }
//        }
        
        disposables.append(state.i.observe { [unowned self] newValue in
            if newValue.routing && newValue.graph == nil {
                DispatchQueue(label: "graph builder").async {
                    let graph = time { buildGraph(tracks: newValue.tracks, url: self.graphURL) }
                    DispatchQueue.main.async { [unowned self] in
                        self.state.change { $0.graph = graph }
                    }
                }
            }
        })

    }
    
    func setTracks(_ t: [Track]) {
        state.change { $0.tracks = t }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        rootView = IBox(view!)
        setMapRect = build(persistent: persistentState, state: state, rootView: rootView)
    }
    
    func resetMapRect() {
        setMapRect?(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        resetMapRect()
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
        }
    }
}
