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

extension NSObjectProtocol {
    /// One-way binding
    func bind<Value>(keyPath: ReferenceWritableKeyPath<Self, Value>, _ i: I<Value>) -> Disposable {
        return i.observe {
            self[keyPath: keyPath] = $0
        }
    }
}

final class PolygonRenderer {
    let renderer: MKPolygonRenderer
    var disposables: [Disposable] = []
    
    init(polygon: MKPolygon, strokeColor: I<UIColor>, alpha: I<CGFloat>, lineWidth: I<CGFloat>) {
        renderer = MKPolygonRenderer(polygon: polygon)
        disposables.append(renderer.bind(keyPath: \.strokeColor, strokeColor.map { $0 }))
        disposables.append(renderer.bind(keyPath: \.alpha, alpha))
        disposables.append(renderer.bind(keyPath: \.lineWidth, lineWidth))
    }
}

extension Comparable {
    func clamped(to: ClosedRange<Self>) -> Self {
        if self < to.lowerBound { return to.lowerBound }
        if self > to.upperBound { return to.upperBound }
        return self
    }
}

struct State: Equatable {
    let tracks: [Track]
    
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
        return lhs.selection == rhs.selection && lhs.trackPosition == rhs.trackPosition
    }
}

final class PointAnnotation {
    let annotation: MKPointAnnotation
    let disposable: Any
    init(_ location: I<CLLocationCoordinate2D>) {
        let annotation = MKPointAnnotation()
        self.annotation = annotation
        disposable = location.observe {
            annotation.coordinate = $0
        }
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

final class ILineView {
    let lineView = LineView()
    var disposables: [Any] = []
    init(position: I<CGFloat?>, points: I<[CGPoint]>, pointsRect: I<CGRect>) {
        disposables.append(lineView.bind(keyPath: \LineView.position, position))
        disposables.append(lineView.bind(keyPath: \LineView.points, points))
        disposables.append(lineView.bind(keyPath: \LineView.pointsRect, pointsRect))
    }
}

func lift<A>(_ f: @escaping (A,A) -> Bool) -> (A?,A?) -> Bool {
    return { l, r in
        switch (l,r) {
        case (nil,nil): return true
        case let (x?, y?): return f(x,y)
        default: return false
        }
    }
}

func time(name: StaticString = #function, line: Int = #line, _ f: () -> ()) {
    let startTime = DispatchTime.now()
    f()
    let endTime = DispatchTime.now()
    let diff = (endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
    print("\(name) (line \(line)): \(diff)")
}

extension UIView {
    func addConstraintsToSizeToParent(spacing: CGFloat = 0) {
        guard let view = superview else { fatalError() }
        let top = topAnchor.constraint(equalTo: view.topAnchor)
        let bottom = bottomAnchor.constraint(equalTo: view.bottomAnchor)
        let left = leftAnchor.constraint(equalTo: view.leftAnchor)
        let right = rightAnchor.constraint(equalTo: view.rightAnchor)
        view.addConstraints([top,bottom,left,right])
        if spacing != 0 {
            top.constant = spacing
            left.constant = spacing
            right.constant = -spacing
            bottom.constant = -spacing
        }
    }
}

final class TrackInfoView {
    private var lineView: ILineView
    var view: UIView! = nil
    let totalAscent = UILabel()
    let totalDistance = UILabel()
    let name = UILabel()
    var disposables: [Any] = []

    // 0...1.0
    var pannedLocation: I<CGFloat> {
        return _pannedLocation.i
    }
    private var _pannedLocation: Var<CGFloat> = Var(0)

    init(position: I<CGFloat?>, points: I<[CGPoint]>, pointsRect: I<CGRect>, track: I<Track?>) {
        lineView = ILineView(position: position, points: points, pointsRect: pointsRect)
        let darkMode = true
        let blurredViewForeground: UIColor = darkMode ? .white : .black

        // Lineview
        lineView.lineView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        lineView.lineView.backgroundColor = .clear
        lineView.lineView.strokeColor = blurredViewForeground
        lineView.lineView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(linePanned(sender:))))

        // Track information
        let trackInfoLabels = [
            name,
            totalDistance,
            totalAscent
        ]
        let trackInfo = UIStackView(arrangedSubviews: trackInfoLabels)
        trackInfo.axis = .horizontal
        trackInfo.distribution = .equalCentering
        trackInfo.heightAnchor.constraint(equalToConstant: 20)
        trackInfo.spacing = 10
        for s in trackInfoLabels {
            s.backgroundColor = .clear
            s.textColor = blurredViewForeground
        }

        let blurredView = UIVisualEffectView(effect: UIBlurEffect(style: darkMode ? .dark : .light))
        blurredView.translatesAutoresizingMaskIntoConstraints = false


        let stackView = UIStackView(arrangedSubviews: [trackInfo, lineView.lineView])
        blurredView.addSubview(stackView)
        stackView.axis = .vertical
        stackView.addConstraintsToSizeToParent(spacing: 10)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        disposables.append(name.bind(keyPath: \UILabel.text, track.map { $0?.name }))

        let formatter = MKDistanceFormatter()
        disposables.append(totalDistance.bind(keyPath: \.text, track.map { track in
            track.map { formatter.string(fromDistance: $0.distance) }
        }))
        disposables.append(totalAscent.bind(keyPath: \.text, track.map { track in
            track.map { "↗ \(formatter.string(fromDistance: $0.ascent))" }
        }))

        view = blurredView
    }

    @objc func linePanned(sender: UIPanGestureRecognizer) {
        let normalizedLocation = (sender.location(in: lineView.lineView).x /
        lineView.lineView.bounds.size.width).clamped(to: 0.0...1.0)
        _pannedLocation.set(normalizedLocation)
    }

}

class ViewController: UIViewController, MKMapViewDelegate {
    let mapView = MKMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: PolygonRenderer] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    var draggedPointAnnotation: PointAnnotation!
    var draggedLocation: I<(distance: Double, location: CLLocation)?>!
    
    let state: Var<State>
    let selection: I<MKPolygon?>
    let hasSelection: I<Bool>

    var disposables: [Any] = []
    let darkMode = true
    var locationManager: CLLocationManager?
    var trackInfoView: TrackInfoView!
    
    var selectedTrack: I<Track?> {
        return selection.map {
            guard let p = $0 else { return nil }
            return self.trackForPolygon[p]
        }
    }
    
    init(tracks: [Track]) {
        state = Var(State(tracks: tracks))
        selection = state.i.map { $0.selection }
        hasSelection = state.i.map { $0.selection != nil }

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
        
        draggedPointAnnotation = PointAnnotation(draggedPoint)
        
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
        trackInfoView = TrackInfoView(position: position, points: points, pointsRect: rect, track: selectedTrack)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.addConstraintsToSizeToParent()
        
        // MapView
        mapView.delegate = self
        disposables.append(state.i.map { $0.tracks }.observe {
            $0.forEach { track in
                let line = track.line
                self.mapView.add(line)
                self.lines[line] = track.color
                self.trackForPolygon[line] = track
            }
        })
        
        let blurredView = trackInfoView.view!
        view.addSubview(blurredView)
        let height: CGFloat = 120
        blurredView.heightAnchor.constraint(greaterThanOrEqualToConstant: height)
        let bottomConstraint = blurredView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        disposables.append(if_(hasSelection, then: I<CGFloat>(constant: 0), else: I(constant: height)).observe { newOffset in
            bottomConstraint.constant = newOffset
            UIView.animate(withDuration: 0.2) {
                self.view.layoutIfNeeded()
            }
        })
        bottomConstraint.isActive = true
        blurredView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        blurredView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        view.backgroundColor = .white
        

        mapView.addAnnotation(draggedPointAnnotation.annotation)

        disposables.append(trackInfoView.pannedLocation.observe { loc in
            self.state.change { $0.trackPosition = loc }
        })


        self.disposables.append(draggedLocation.observe { x in
            guard let (_, location) = x else { return }
            // todo subtract the height of the trackInfo box (if selected)
            if !self.mapView.annotations(in: self.mapView.visibleMapRect).contains(self.draggedPointAnnotation.annotation) {
                self.mapView.setCenter(location.coordinate, animated: true)
            }
        })
    }
    
    override func viewDidAppear(_ animated: Bool) {
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        mapView.setVisibleMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)), edgePadding: UIEdgeInsetsMake(10, 10, 10, 10), animated: true)
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped(sender:))))
        
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager = CLLocationManager()
            locationManager!.requestWhenInUseAuthorization()
        }
    }
    
    
    @objc func mapTapped(sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView)
        let mapPoint = MKMapPointForCoordinate(mapView.convert(point, toCoordinateFrom: mapView))
        let possibilities = lines.keys.filter { line in
            let renderer = renderers[line]!.renderer
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

    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let line = overlay as? MKPolygon {
            if let renderer = renderers[line] { return renderer.renderer }
            let renderer = buildRenderer(line)
            renderers[line] = renderer
            return renderer.renderer
        }
        return MKOverlayRenderer()
    }
    
    func buildRenderer(_ line: MKPolygon) -> PolygonRenderer {
        let isSelected: I<Bool> = selection.map { $0 == line }
        let shouldHighlight: I<Bool> = !hasSelection || isSelected
        let strokeColor: I<UIColor> = I(constant: lines[line]!.uiColor)
        let alpha: I<CGFloat> = if_(shouldHighlight, then: I(constant: 1), else: I(constant: 0.5))
        let lineWidth: I<CGFloat> = if_(shouldHighlight, then: I(constant: 3), else: I(constant: 0.5))
        return PolygonRenderer(polygon: line, strokeColor: strokeColor, alpha: alpha, lineWidth: lineWidth)
    }
}

