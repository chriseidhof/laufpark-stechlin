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

struct DisplayState: Equatable, Codable {
    var tracks: [Track]
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
    
    
    // MapView
    mapView.delegate = MapViewDelegate(rendererForOverlay: { [unowned mapView] mapView_, overlay in
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            mapView.disposables.append(renderer)
            return renderer.unbox
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
                return result
            }
    }, regionDidChangeAnimated: { [unowned mapView] _ in
        print(mapView.unbox.region)
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

final class ViewController: NSViewController {
    @IBOutlet var _mapView: MKMapView!
    
    let storedState = Input<StoredState>(StoredState(annotationsVisible: true, satellite: true, showConfiguration: false))
    let state = Input(DisplayState(tracks: []))
    var rootView: IBox<NSView>!
    
    override func viewDidLoad() {
        rootView = IBox(view)
        let setMapRect = addMapView(persistent: storedState, state: state, rootView: rootView)
        setMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)))
        loadTracks()
    }
    
    func loadTracks() {
        DispatchQueue(label: "async").async {
            let tracks = Track.load()
            DispatchQueue.main.async {
                self.state.change { $0.tracks = Array(tracks) }
                
            }
        }
    }
}
