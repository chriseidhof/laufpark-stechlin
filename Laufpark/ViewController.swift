//
//  ViewController.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

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
        disposables.append(renderer.bind(keyPath: \MKPolygonRenderer.strokeColor, strokeColor.map { $0 }))
        disposables.append(renderer.bind(keyPath: \.alpha, alpha))
        disposables.append(renderer.bind(keyPath: \.lineWidth, lineWidth))
    }
}

struct State: Equatable {
    var selection: MKPolygon? {
        didSet {
            trackPosition = nil
        }
    }
    var trackPosition: CGFloat? // 0...1
    
    init() {
        selection = nil
        trackPosition = nil
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

class ViewController: UIViewController, MKMapViewDelegate {
    let tracks: [Track]
    let mapView = MKMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: PolygonRenderer] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    var lineView: ILineView!
    var stackView: UIStackView = UIStackView(arrangedSubviews: [])
    let totalAscent = UILabel()
    let totalDistance = UILabel()
    let name = UILabel()
    var draggedPointAnnotation: PointAnnotation!
    var draggedLocation: I<(distance: Double, location: CLLocation)?>!
    
    let state = Var<State>(value: State())
    let selection: I<MKPolygon?>
    let hasSelection: I<Bool>

    var disposables: [Any] = []
    
    var selectedTrack: I<Track?> {
        return selection.map {
            guard let p = $0 else { return nil }
            return self.trackForPolygon[p]
        }
    }
    
    init(tracks: [Track]) {
        self.tracks = tracks
        selection = state.i.map { $0.selection }
        hasSelection = state.i.map { $0.selection != nil }

        super.init(nibName: nil, bundle: nil)

        draggedLocation = state.i.map(eq: lift(==), { [weak self] state in
            guard let s = state.selection,
                let track = self?.trackForPolygon[s],
                let location = state.trackPosition else { return nil }
            let distance = Double(location) * track.distance
            let point = track.point(at: distance)!
            return (distance: distance, location: point)
        })

        let draggedPoint: I<CLLocationCoordinate2D> = draggedLocation.map { (x: (distance: CLLocationDistance, location: CLLocation)?) in x?.location.coordinate ?? CLLocationCoordinate2D() }
        
        draggedPointAnnotation = PointAnnotation(draggedPoint)
        
        let position: I<CGFloat?> = draggedLocation.map {
            ($0?.distance).map { CGFloat($0) }
        }
        
        let elevations: I<Track.ElevationProfile?> = selectedTrack.map(eq: { _, _ in false }) { track in
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
        
        lineView = ILineView(position: position, points: points, pointsRect: rect)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        view.addSubview(stackView)
        stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        stackView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        stackView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        stackView.distribution = .fill
        stackView.axis = .vertical
        stackView.backgroundColor = .green
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Lineview
        lineView.lineView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        lineView.lineView.backgroundColor = .white
        lineView.lineView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(linePanned(sender:))))
        
        // MapView
        mapView.delegate = self
        tracks.forEach {
            let line = $0.line
            mapView.add(line)
            lines[line] = $0.color
            trackForPolygon[line] = $0
        }
        
        // Track information
        let trackInfo = UIStackView(arrangedSubviews: [
            name,
            totalDistance,
            totalAscent
        ])
        trackInfo.axis = .horizontal
        trackInfo.distribution = .equalCentering
        trackInfo.heightAnchor.constraint(equalToConstant: 20)
        for s in trackInfo.arrangedSubviews { s.backgroundColor = .white }
        
        stackView.addArrangedSubview(mapView)
        stackView.addArrangedSubview(trackInfo)
        stackView.addArrangedSubview(lineView.lineView)
        view.backgroundColor = .white
        
        disposables.append(name.bind(keyPath: \UILabel.text, selectedTrack.map { $0?.name }))
        
        let formatter = MKDistanceFormatter()
        disposables.append(totalDistance.bind(keyPath: \.text, selectedTrack.map { track in
            track.map { formatter.string(fromDistance: $0.distance) }
        }))
        disposables.append(totalDistance.bind(keyPath: \.text, selectedTrack.map { track in
            track.map { "↗ \(formatter.string(fromDistance: $0.ascent))" }
        }))

        mapView.addAnnotation(draggedPointAnnotation.annotation)

        self.disposables.append(draggedLocation.observe { x in
            guard let (distance, location) = x else { return }
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
    }
    
    @objc func linePanned(sender: UIPanGestureRecognizer) {
        let normalizedLocation = sender.location(in: lineView.lineView).x / lineView.lineView.bounds.size.width
        state.change { $0.trackPosition = normalizedLocation }
        
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
        let strokeColor: I<UIColor> = I(value: lines[line]!.uiColor)
        let alpha: I<CGFloat> = if_(shouldHighlight, then: I(value: 1), else: I(value: 0.5))
        let lineWidth: I<CGFloat> = if_(shouldHighlight, then: I(value: 3), else: I(value: 0.5))
        return PolygonRenderer(polygon: line, strokeColor: strokeColor, alpha: alpha, lineWidth: lineWidth)
    }
}

