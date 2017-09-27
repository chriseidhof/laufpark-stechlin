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
    
    var selection: MKPolygon? {
        didSet {
            trackPosition = nil
        }
    }
    var trackPosition: CGFloat? // 0...1
    
    init(tracks: [Track]) {
        selection = nil
        trackPosition = nil
        self.tracks = tracks
    }
    
    static func ==(lhs: State, rhs: State) -> Bool {
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks
    }
}

class ViewController: UIViewController, MKMapViewDelegate {
    let mapView: IBox<MKMapView> = buildMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: IBox<MKPolygonRenderer>] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    var draggedPointAnnotation: IBox<MKPointAnnotation>!
    var draggedLocation: I<(distance: Double, location: CLLocation)?>!
    var rootView: IBox<UIView>!
    
    let state: Input<State>
    let selection: I<MKPolygon?>
    let hasSelection: I<Bool>

    var disposables: [Any] = []
    var locationManager: CLLocationManager?
    var trackInfoView: TrackInfoView!
    let darkMode: I<Bool>
    var timer: Disposable?

    var selectedTrack: I<Track?> {
        return selection.map {
            guard let p = $0 else { return nil }
            return self.trackForPolygon[p]
        }
    }
    
    init() {
        state = Input(State(tracks: []))
        selection = state.i.map { $0.selection }
        hasSelection = state.i.map { $0.selection != nil }
        darkMode = mapView[\.mapType] == .standard

        super.init(nibName: nil, bundle: nil)

        draggedLocation = state.i.map(eq: lift(==), { [weak self] state in
            guard let s = state.selection,
                let track = self?.trackForPolygon[s],
                let location = state.trackPosition else { return nil }
            let distance = Double(location) * track.distance
            guard let point = track.point(at: distance) else { return nil }
            return (distance: distance, location: point)
        })

        let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map {
            $0?.location.coordinate ?? CLLocationCoordinate2D()
        }
        
        draggedPointAnnotation = annotation(location: draggedPoint)
        
        let position: I<CGFloat?> = draggedLocation.map {
            ($0?.distance).map { CGFloat($0) }
        }
        
        let elevations = selectedTrack.map(eq: { _, _ in false }) { track in
            track?.elevationProfile
        }
        
        let points: I<[CGPoint]> = elevations.map(eq: ==) { ele in
            ele.map { profile in
                profile.map { CGPoint(x: $0.distance, y: $0.elevation) }
            } ?? []
        }
        
        let rect: I<CGRect> = elevations.map { profile in
            guard let profile = profile else { return .zero }
            let elevations = profile.map { $0.elevation }
            return CGRect(x: 0, y: elevations.min()!, width: profile.last!.distance.rounded(.up), height: elevations.max()!-elevations.min()!)
        }
        
        trackInfoView = TrackInfoView(position: position, points: points, pointsRect: rect, track: selectedTrack, darkMode: darkMode)
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
        disposables.append(state.i.map { $0.tracks }.observe {
            $0.forEach { track in
                let line = track.line
                self.lines[line] = track.color
                self.trackForPolygon[line] = track
                self.mapView.unbox.add(line)
            }
        })
        
        let blurredView = trackInfoView.view!
        view.addSubview(blurredView)
        let height: CGFloat = 120
        blurredView.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
        let bottomConstraint = blurredView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        disposables.append(if_(hasSelection, then: 0, else: height).observe { newOffset in
            bottomConstraint.constant = newOffset
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        })
        bottomConstraint.isActive = true
        blurredView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        blurredView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        view.backgroundColor = .white
        

        mapView.unbox.addAnnotation(draggedPointAnnotation.unbox)
        
        disposables.append(trackInfoView.pannedLocation.observe { loc in
            self.state.change { $0.trackPosition = loc }
        })


        self.disposables.append(draggedLocation.observe { x in
            guard let (_, location) = x else { return }
            // todo subtract the height of the trackInfo box (if selected)
            if !self.mapView.unbox.annotations(in: self.mapView.unbox.visibleMapRect).contains(self.draggedPointAnnotation.unbox) {
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
        let possibilities = lines.keys.filter { line in
            let renderer = renderers[line]!.unbox
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point)
        }
        
        // in case of multiple matches, toggle between the selections, and start out with the smallest route
        if let s = selection.value ?? nil, possibilities.count > 1 && possibilities.contains(s) {
            state.change {
                $0.selection = possibilities.lazy.sorted { $0.pointCount < $1.pointCount }.first(where: { $0 != s })
            }
        } else {
            state.change { $0.selection = possibilities.first }
        }
    }

    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        resetMapRect()
        
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let line = overlay as? MKPolygon {
            if let renderer = renderers[line] { return renderer.unbox }
            let renderer = buildRenderer(line)
            renderers[line] = renderer
            return renderer.unbox
        }
        return MKOverlayRenderer()
    }
    
    func buildRenderer(_ line: MKPolygon) -> IBox<MKPolygonRenderer> {
        let isSelected = selection.map { $0 == line }
        let shouldHighlight = !hasSelection || isSelected
        let lineColor = lines[line]!.uiColor
        let fillColor = if_(isSelected, then: lineColor.withAlphaComponent(0.2), else: lineColor.withAlphaComponent(0.1))
        return polygonRenderer(polygon: line,
                               strokeColor: I(constant: lineColor),
                               fillColor: fillColor.map { $0 },
                               alpha: if_(shouldHighlight, then: I(constant: 1.0), else: if_(darkMode, then: 0.5, else: 1.0)),
                               lineWidth: if_(shouldHighlight, then: I(constant: 3.0), else: if_(darkMode, then: 1.0, else: 1.0)))
    }
}

