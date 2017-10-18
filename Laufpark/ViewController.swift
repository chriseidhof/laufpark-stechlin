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
    var satellite: Bool = false
    var showConfiguration: Bool = false
    
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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition && lhs.tracks == rhs.tracks && lhs.annotationsVisible == rhs.annotationsVisible && lhs.satellite == rhs.satellite && lhs.showConfiguration == rhs.showConfiguration
    }
}

func uiSwitch(valueChange: @escaping (Bool) -> ()) -> IBox<UISwitch> {
    let view = UISwitch()
    let result = IBox(view)
    result.handle(.valueChanged) { [unowned view] in
        valueChange(view.isOn)
    }
    return result
}

class ViewController: UIViewController, MKMapViewDelegate {
    let mapView: IBox<MKMapView> = buildMapView()
    var tracks: [MKPolygon:Track] = [:]
    
    var draggedLocation: I<(distance: Double, location: CLLocation)?>!
    var rootView: IBox<UIView>!
    
    let state: Input<State>

    var disposables: [Any] = []
    var locationManager: CLLocationManager?
    let darkMode: I<Bool>

    init() {
        state = Input(State(tracks: []))
        darkMode = state[\.satellite]

        super.init(nibName: nil, bundle: nil)

        draggedLocation = state.i.map(eq: lift(==), { state in
            guard let track = state.selection,
                let location = state.trackPosition else { return nil }
            let distance = Double(location) * track.distance
            guard let point = track.point(at: distance) else { return nil }
            return (distance: distance, location: point)
        })
    }
    
    func setTracks(_ t: [Track]) {
        state.change { $0.tracks = t }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        rootView = IBox(view)
        rootView.addSubview(mapView, constraints: sizeToParent())
        
        let changeState: ((inout State) -> ()) -> () = { [unowned self] f in
            self.state.change(f)
        }
        
        
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
        mapView.bind(annotations: POI.all.map { poi in MKPointAnnotation(coordinate: poi.location, title: poi.name) }, visible: state[\.annotationsVisible])

        // Track Info View
        let position: I<CGFloat?> = draggedLocation.map { ($0?.distance).map { CGFloat($0) } }
        let elevations = state.i[\.selection].map(eq: { _, _ in false }) { $0?.elevationProfile }
        let points: I<[LineView.Point]> = elevations.map { ele in
            ele.map { profile in
                profile.map { LineView.Point(x: $0.distance, y: $0.elevation) }
            } ?? []
        }
        let (trackInfo, location) = trackInfoView(position: position, points: points, track: state.i[\.selection], darkMode: darkMode)
        disposables.append(location.observe { loc in
            changeState { $0.trackPosition = loc }
        })
        
        func switchWith(label text: String, textColor: I<UIColor>, action: @escaping (Bool) -> ()) -> IBox<UIView> {
            let switchLabel = label(text: I(constant: text), textColor: textColor.map { $0 } )
            switchLabel.unbox.widthAnchor.constraint(equalToConstant: 100)
            let switch_ = uiSwitch(valueChange: action)
            let stack = stackView(arrangedSubviews: [switchLabel.cast, switch_.cast], axis: .horizontal)
            stack.unbox.heightAnchor.constraint(equalToConstant: 40)
            return stack.cast
        }
        
        let textColor = darkMode.map { $0 ? UIColor.white : .black }
        let backgroundColor = darkMode.map { $0 ? UIColor.black : .white }
        // Configuration View
        let accomodation = switchWith(label: NSLocalizedString("Unterkünfte", comment: ""), textColor: textColor, action: { value in changeState {
            $0.annotationsVisible = value
        }})
        let satellite = switchWith(label: NSLocalizedString("Satellit", comment: ""), textColor: textColor, action: { value in changeState {
            $0.satellite = value
        }})
        
        let divider = IBox(UIView())
        divider.bind(textColor.map { $0.withAlphaComponent(0.1) }, to: \.backgroundColor)
        divider.unbox.heightAnchor.constraint(equalToConstant: 1).isActive = true
        divider.bind(!(state.i[\.hasSelection] && state.i[\.showConfiguration]), to: \.hidden)

        let trackInfoHeight: CGFloat = 120
        trackInfo.bind(state.i[\.hasSelection].map { !$0 }, to: \.isHidden)
        trackInfo.unbox.heightAnchor.constraint(equalToConstant: trackInfoHeight).isActive = true
        
        // Blurred Bottom View
        let infoStackView = stackView(arrangedSubviews: [trackInfo, divider, accomodation.cast, satellite.cast])

        let inset: CGFloat = 10
        let blurredView = effectView(effect: darkMode.map { UIBlurEffect(style: $0 ? .dark : .light)})
        blurredView.addSubview(infoStackView, path: \.contentView, constraints: [equal(\.leftAnchor, constant: -inset), equal(\.topAnchor, constant: -inset), equal(\.rightAnchor, constant: inset)])
        rootView.addSubview(blurredView, constraints: [
            equal(\.leftAnchor), equal(\.rightAnchor)
        ])
        let heightConstraint = blurredView.unbox.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        let bottomConstraint = blurredView.unbox.topAnchor.constraint(equalTo: view.bottomAnchor)
        
        
        let configurationHeight: I<CGFloat> = if_(state.i[\.showConfiguration], then: 100, else: 0)
        let selectionHeight: I<CGFloat> = if_(state.i[\.hasSelection], then: trackInfoHeight + 2 * inset, else: 0)
        
        disposables.append((selectionHeight + configurationHeight).observe { newHeight in
            bottomConstraint.constant = -newHeight
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        })
        NSLayoutConstraint.activate([heightConstraint, bottomConstraint])
        
        // Dragged Point Annotation
        let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map {
            $0?.location.coordinate ?? CLLocationCoordinate2D()
        }
        let draggedPointAnnotation = annotation(location: draggedPoint)
        mapView.unbox.addAnnotation(draggedPointAnnotation.unbox)
        mapView.bind(state.i.map { $0.satellite ? .satellite : .standard }, to: \.mapType)

        // Center the map location on position dragging
        self.disposables.append(draggedLocation.observe { x in
            guard let (_, location) = x else { return }
            // todo subtract the height of the trackInfo box (if selected)
            if !self.mapView.unbox.annotations(in: self.mapView.unbox.visibleMapRect).contains(draggedPointAnnotation.unbox) {
                self.mapView.unbox.setCenter(location.coordinate, animated: true)
            }
        })

        // Loading Indicator
        let isLoading = state[\.loading]
        let loadingIndicator = activityIndicator(style: darkMode.map { $0 ? .gray : .white }, animating: isLoading)
        rootView.addSubview(loadingIndicator, constraints: [equal(\.centerXAnchor), equal(\.centerXAnchor)])
        
        // Toggle Map Button
        let toggleMapButton = button(type: .custom, title: I(constant: "…"), backgroundColor: I(constant: UIColor(white: 1, alpha: 0.8)), titleColor: I(constant: .black), onTap: {
            changeState { $0.showConfiguration.toggle() }
        })
        toggleMapButton.unbox.layer.cornerRadius = 3
        rootView.addSubview(toggleMapButton, constraints: [equal(\.topAnchor, constant: -25), equal(\.trailingAnchor, constant: 10)])
        
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

