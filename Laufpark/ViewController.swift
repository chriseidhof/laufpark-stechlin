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

struct State: Equatable {
    var tracks: [Track]
    var loading: Bool { return tracks.isEmpty }
    var annotationsVisible: Bool = false
    
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
    
    static func ==(lhs: State, rhs: State) -> Bool {
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.annotationsVisible == rhs.annotationsVisible
    }
}

class ViewController: UIViewController, MKMapViewDelegate {
    let mapView: IBox<MKMapView> = buildMapView()
    var tracks: [MKPolygon:Track] = [:]
    
    var draggedLocation: I<(distance: Double, location: CLLocation)?>!
    var rootView: IBox<UIView>!
    
    let state: Input<State>

    var disposables: [Any] = []
    var locationManager: CLLocationManager?
    var trackInfoView: TrackInfoView!
    let darkMode: I<Bool>

    init() {
        state = Input(State(tracks: []))
        darkMode = mapView[\.mapType] == .standard

        super.init(nibName: nil, bundle: nil)

        draggedLocation = state.i.map(eq: lift(==), { state in
            guard let track = state.selection,
                let location = state.trackPosition else { return nil }
            let distance = Double(location) * track.distance
            guard let point = track.point(at: distance) else { return nil }
            return (distance: distance, location: point)
        })
        
        let position: I<CGFloat?> = draggedLocation.map {
            ($0?.distance).map { CGFloat($0) }
        }
        
        let elevations = state.i[\.selection].map(eq: { _, _ in false }) { track in
            track?.elevationProfile
        }
        
        let points: I<[LineView.Point]> = elevations.map(eq: ==) { ele in
            ele.map { profile in
                profile.map { LineView.Point(x: $0.distance, y: $0.elevation) }
            } ?? []
        }
        
        trackInfoView = TrackInfoView(position: position, points: points, track: state.i[\.selection], darkMode: darkMode)
    }
    
    func setTracks(_ t: [Track]) {
        state.change { $0.tracks = t }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        rootView = IBox(view!)
        rootView.addSubview(mapView)
        mapView.unbox.translatesAutoresizingMaskIntoConstraints = false
        mapView.unbox.addConstraintsToSizeToParent()
        
        // MapView
        mapView.unbox.delegate = self
        disposables.append(state.i.map { $0.tracks }.observe { [unowned self] in
            self.mapView.unbox.removeOverlays(self.mapView.unbox.overlays)
            $0.forEach { track in
                let polygon = track.polygon
                self.tracks[polygon] = track
                self.mapView.unbox.add(polygon)
            }
        })
        
        let blurredView = trackInfoView.view!
        view.addSubview(blurredView)
        let height: CGFloat = 120
        blurredView.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
        let bottomConstraint = blurredView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        disposables.append(if_(state.i[\.hasSelection], then: 0, else: height).observe { newOffset in
            bottomConstraint.constant = newOffset
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        })
        bottomConstraint.isActive = true
        blurredView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        blurredView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        view.backgroundColor = .white
        
        let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map {
            $0?.location.coordinate ?? CLLocationCoordinate2D()
        }
        let draggedPointAnnotation = annotation(location: draggedPoint)
        mapView.unbox.addAnnotation(draggedPointAnnotation.unbox)
        
        disposables.append(trackInfoView.pannedLocation.observe { loc in
            self.state.change { $0.trackPosition = loc }
        })


        self.disposables.append(draggedLocation.observe { x in
            guard let (_, location) = x else { return }
            // todo subtract the height of the trackInfo box (if selected)
            if !self.mapView.unbox.annotations(in: self.mapView.unbox.visibleMapRect).contains(draggedPointAnnotation.unbox) {
                self.mapView.unbox.setCenter(location.coordinate, animated: true)
            }
        })

        let isLoading = state[\.loading]
        let loadingIndicator = activityIndicator(style: darkMode.map { $0 ? .gray : .white }, animating: isLoading)
        rootView.addSubview(loadingIndicator, constraints: [equalCenterX(), equalCenterY()])
        
        let toggleMapButton = button(type: .custom, titleImage: I(constant: UIImage(named: "map")!), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: { [unowned self] in
            self.mapView.unbox.mapType = self.mapView.unbox.mapType == .standard ? .hybrid : .standard
        })
        rootView.addSubview(toggleMapButton, constraints: [equalTop(offset: -25), equalRight(offset: 10)])
        
        let toggleAnnotation = button(type: .custom, title: I(constant: "i"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: { [unowned self] in
            self.state.change { $0.annotationsVisible = !$0.annotationsVisible }
        })
        rootView.addSubview(toggleAnnotation, constraints: [equalTop(offset: -55), equalRight(offset: 10)])
        let annotations: [MKPointAnnotation] = POI.all.map { poi in
            let annotation = MKPointAnnotation()
            annotation.coordinate = poi.location
            annotation.title = poi.name
            return annotation
        }

        disposables.append(state[\.annotationsVisible].observe { [unowned self] visible in
            if visible {
                self.mapView.unbox.addAnnotations(annotations)
            } else {
                self.mapView.unbox.removeAnnotations(annotations)
            }
        })
    }
    
    func resetMapRect() {
        mapView.unbox.setVisibleMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)), edgePadding: UIEdgeInsetsMake(10, 10, 10, 10), animated: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        resetMapRect()
        mapView.unbox.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped(sender:))))
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
        }
    }
    
    
    @objc func mapTapped(sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView.unbox)
        let mapPoint = MKMapPointForCoordinate(mapView.unbox.convert(point, toCoordinateFrom: mapView.unbox))
        let possibilities = tracks.filter { (polygon, track) in
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

    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        resetMapRect()
        
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = buildRenderer(polygon)
            self.mapView.disposables.append(renderer)
            return renderer.unbox
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
    }
    
    func buildRenderer(_ polygon: MKPolygon) -> IBox<MKPolygonRenderer> {
        let track = tracks[polygon]!
        let isSelected = state.i[\.selection].map { $0 == track }
        let shouldHighlight = !state.i[\.hasSelection] || isSelected
        let lineColor = tracks[polygon]!.color.uiColor
        let fillColor = if_(isSelected, then: lineColor.withAlphaComponent(0.2), else: lineColor.withAlphaComponent(0.1))
        return polygonRenderer(polygon: polygon,
                               strokeColor: I(constant: lineColor),
                               fillColor: fillColor.map { $0 },
                               alpha: if_(shouldHighlight, then: I(constant: 1.0), else: if_(darkMode, then: 0.5, else: 1.0)),
                               lineWidth: if_(shouldHighlight, then: I(constant: 3.0), else: if_(darkMode, then: 1.0, else: 1.0)))
    }
}

