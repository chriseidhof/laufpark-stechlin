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

final class Box<A> {
    let unbox: A
    var references: [Any] = []
    
    init(_ value: A) {
        self.unbox = value
    }
}

extension Box where A: UIActivityIndicatorView {
    func bindIsAnimating(to isAnimating: I<Bool>) {
        let disposable = isAnimating.observe { [unowned self] isLoading in
            if isLoading {
                self.unbox.startAnimating()
            } else {
                self.unbox.stopAnimating()
            }
        }
        references.append(disposable)
    }
}

extension Box where A: UIView {
    func addSubview<V: UIView>(_ view: Box<V>) {
        unbox.addSubview(view.unbox)
        references.append(view)
    }
    
    func addConstraint(_ constraint: Box<NSLayoutConstraint>) {
        references.append(constraint)
    }
}

extension Box where A: NSLayoutConstraint {
    func bindIsActive(to isActive: I<Bool>) {
        references.append(isActive.observe { [unowned self] active in
            self.unbox.isActive = active
        })
    }
}


struct State: Equatable {
    var tracks: [Track]
    var loading: Bool { return tracks.isEmpty }
    
    var selection: MKPolygon? {
        didSet {
            trackPosition = nil
        }
    }
 
    var trackPosition: CGFloat? // 0...1
    
    var hasSelection: Bool { return selection != nil }
    
    init(tracks: [Track]) {
        selection = nil
        trackPosition = nil
        self.tracks = tracks
    }
    
    static func ==(lhs: State, rhs: State) -> Bool {
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks
    }
}

final class ViewController: UIViewController {
    private let mapView: MKMapView = buildMapView()
    private let positionAnnotation = MKPointAnnotation()
    private let trackInfoView = TrackInfoView()
    

    private var stateInput: Input<State> = Input(State(tracks: []))
    private var state: I<State> {
        return stateInput.i
    }
    private var _state: State = State(tracks: []) {
        didSet {
            stateInput.write(_state)
            update(old: oldValue)
        }
    }

    private var polygons: [MKPolygon: Track] = [:]
    private var locationManager: CLLocationManager?
    private var rootView: Box<UIView>!

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    func setTracks(_ t: [Track]) {
        _state.tracks = t
    }

    override func viewDidLoad() {
        view.backgroundColor = .white
        rootView = Box(view)

        // Configuration
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped(sender:))))
        mapView.addAnnotation(positionAnnotation)
        trackInfoView.panGestureRecognizer.addTarget(self, action: #selector(didPanProfile))

        // Layout
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.addConstraintsToSizeToParent()
        mapView.delegate = self

        let trackInfoBox = Box(trackInfoView)
        rootView.addSubview(trackInfoBox)
        
        trackInfoView.translatesAutoresizingMaskIntoConstraints = false
        let trackInfoConstraint = trackInfoView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let trackInfoConstraintBox = Box(trackInfoConstraint)
        
        trackInfoConstraint.priority = .required
        let hideTrackInfoConstraint = trackInfoView.topAnchor.constraint(equalTo: view.bottomAnchor)
        hideTrackInfoConstraint.priority = .defaultHigh
        NSLayoutConstraint.activate([
            hideTrackInfoConstraint,
            trackInfoView.leftAnchor.constraint(equalTo: view.leftAnchor),
            trackInfoView.rightAnchor.constraint(equalTo: view.rightAnchor),
            trackInfoView.heightAnchor.constraint(equalToConstant: 120)
        ])
        trackInfoConstraintBox.bindIsActive(to: state.map { $0.hasSelection })
        trackInfoBox.addConstraint(trackInfoConstraintBox)

        let loadingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        loadingIndicator.hidesWhenStopped = true
        let box = Box(loadingIndicator)
        box.bindIsAnimating(to: state.map { $0.loading })
        rootView.addSubview(box)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        resetMapRect()
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
        }
    }
    
    private func update(old: State) {
        if _state.tracks != old.tracks {
            mapView.removeOverlays(mapView.overlays)
            for track in _state.tracks {
                let polygon = track.polygon
                polygons[polygon] = track
                mapView.add(polygon)
            }
        }
        if _state.selection != old.selection {
            for polygon in polygons.keys {
                guard let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer else { continue }
                renderer.configure(color: polygons[polygon]!.color.uiColor, selected: !_state.hasSelection)
            }
            if let selectedPolygon = _state.selection, let renderer = mapView.renderer(for: selectedPolygon) as? MKPolygonRenderer {
                renderer.configure(color: polygons[selectedPolygon]!.color.uiColor, selected: true)
            }
            trackInfoView.track = _state.selection.flatMap { polygons[$0] }
        }
        if _state.trackPosition != old.trackPosition {
            trackInfoView.position = _state.trackPosition
            if let position = _state.trackPosition, let selection = _state.selection, let track = polygons[selection] {
                let distance = Double(position) * track.distance
                if let point = track.point(at: distance) {
                    positionAnnotation.coordinate = point.coordinate
                }
            } else {
                positionAnnotation.coordinate = CLLocationCoordinate2D()
            }
        }
    }

    private func resetMapRect() {
        mapView.setVisibleMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)), edgePadding: UIEdgeInsetsMake(10, 10, 10, 10), animated: true)
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        resetMapRect()
    }

    @objc func mapTapped(sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView)
        let mapPoint = MKMapPointForCoordinate(mapView.convert(point, toCoordinateFrom: mapView))
        let possibilities = polygons.keys.filter { polygon in
            guard let renderer = mapView.renderer(for: polygon) as? MKPolygonRenderer else { return false }
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point)
        }
        
        // in case of multiple matches, toggle between the selections, and start out with the smallest route
        if let s = _state.selection, possibilities.count > 1 && possibilities.contains(s) {
            _state.selection = possibilities.lazy.sorted { $0.pointCount < $1.pointCount }.first(where: { $0 != s })
        } else {
            _state.selection = possibilities.first
        }
    }
    
    @objc func didPanProfile(sender: UIPanGestureRecognizer) {
        let normalizedPosition = (sender.location(in: trackInfoView).x / trackInfoView.bounds.size.width).clamped(to: 0.0...1.0)
        _state.trackPosition = normalizedPosition
    }
}


extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let polygon = overlay as? MKPolygon else { return MKOverlayRenderer() }
        if let renderer = mapView.renderer(for: overlay) { return renderer }
        let renderer = MKPolygonRenderer(polygon: polygon)
        let isSelected = _state.selection == polygon
        renderer.configure(color: polygons[polygon]!.color.uiColor, selected: isSelected || !_state.hasSelection)
        return renderer
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let pointAnnotation = annotation as? MKPointAnnotation, pointAnnotation == positionAnnotation else { return nil }
        let result = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
        result.pinTintColor = .red
        return result
    }
}


extension MKPolygonRenderer {
    func configure(color: UIColor, selected: Bool) {
        strokeColor = color
        fillColor = selected ? color.withAlphaComponent(0.2) : color.withAlphaComponent(0.1)
        lineWidth = selected ? 3 : 1
    }
}


