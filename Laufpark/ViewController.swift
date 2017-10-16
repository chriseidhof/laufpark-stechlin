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
        let disposable = isAnimating.observe { isLoading in
            if isLoading {
                self.unbox.startAnimating()
            } else {
                self.unbox.stopAnimating()
            }
        }
        references.append(disposable)
    }
}

extension Box {
    func bind<Property>(_ keyPath: ReferenceWritableKeyPath<A, Property>, to mapType: I<Property>) {
        references.append(mapType.observe { [unowned self] value in
            self.unbox[keyPath: keyPath] = value
        })
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


extension Box where A: UIControl {
    func handle(_ events: UIControlEvents, _ handler: @escaping () -> ()) {
        let target = TargetAction(handler)
        unbox.addTarget(target, action: #selector(TargetAction.action), for: .touchUpInside)
        references.append(target)
    }
}

final class TargetAction {
    let handler: () -> ()
    init(_ handler: @escaping () -> ()) {
        self.handler = handler
    }
    
    @objc func action() {
        handler()
    }
}

struct State: Equatable {
    var tracks: [Track]
    var loading: Bool { return tracks.isEmpty }
    var satellite: Bool = false
    
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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.satellite == rhs.satellite
    }
}

final class ViewController: UIViewController {
    private let mapView = Box(buildMapView())
    private var _mapView: MKMapView { return mapView.unbox }
    
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
        _mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped(sender:))))
        _mapView.addAnnotation(positionAnnotation)
        trackInfoView.panGestureRecognizer.addTarget(self, action: #selector(didPanProfile))

        // Layout
        view.addSubview(_mapView)
        _mapView.translatesAutoresizingMaskIntoConstraints = false
        _mapView.addConstraintsToSizeToParent()
        _mapView.delegate = self
        mapView.bind(\.mapType, to: state.map { $0.satellite ? MKMapType.satellite : .standard })

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
        trackInfoConstraintBox.bind(\.isActive, to: state.map { $0.hasSelection })
        trackInfoBox.addConstraint(trackInfoConstraintBox)
        trackInfoBox.bind(\.darkMode, to: state.map { $0.satellite })

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
        
        let toggleMapButton = Box(UIButton(type: .roundedRect))
        toggleMapButton.unbox.setTitle("Toggle", for: .normal)
        toggleMapButton.handle(.touchUpInside) { [unowned self] in
            self._state.satellite = !self._state.satellite
        }
        
        mapView.addSubview(toggleMapButton)
        toggleMapButton.unbox.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toggleMapButton.unbox.trailingAnchor.constraint(equalTo: mapView.unbox.safeAreaLayoutGuide.trailingAnchor),
            toggleMapButton.unbox.topAnchor.constraint(equalTo: mapView.unbox.safeAreaLayoutGuide.topAnchor)
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
            _mapView.removeOverlays(_mapView.overlays)
            for track in _state.tracks {
                let polygon = track.polygon
                polygons[polygon] = track
                _mapView.add(polygon)
            }
        }
        if _state.selection != old.selection {
            for polygon in polygons.keys {
                guard let renderer = _mapView.renderer(for: polygon) as? MKPolygonRenderer else { continue }
                renderer.configure(color: polygons[polygon]!.color.uiColor, selected: !_state.hasSelection)
            }
            if let selectedPolygon = _state.selection, let renderer = _mapView.renderer(for: selectedPolygon) as? MKPolygonRenderer {
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
        _mapView.setVisibleMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)), edgePadding: UIEdgeInsetsMake(10, 10, 10, 10), animated: true)
    }
    
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        resetMapRect()
    }

    @objc func mapTapped(sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: _mapView)
        let mapPoint = MKMapPointForCoordinate(_mapView.convert(point, toCoordinateFrom: _mapView))
        let possibilities = polygons.keys.filter { polygon in
            guard let renderer = _mapView.renderer(for: polygon) as? MKPolygonRenderer else { return false }
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


