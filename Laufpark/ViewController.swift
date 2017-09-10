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

class ViewController: UIViewController, MKMapViewDelegate {
    let tracks: [Track]
    let mapView = MKMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: PolygonRenderer] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    let lineView = LineView()
    var stackView: UIStackView = UIStackView(arrangedSubviews: [])
    let totalAscent = UILabel()
    let totalDistance = UILabel()
    let name = UILabel()
    let draggedPointAnnotation = MKPointAnnotation()
    let selection = Var<MKPolygon?>(nil, eq: ==)
    let hasSelection: I<Bool>

    var disposables: [Any] = []
    
//    var selection: MKPolygon? {
//        didSet {
//            updateForSelection()
//            if let t = selectedTrack {
//            }
//        }
//    }
    
    var selectedTrack: I<Track?> {
        return selection.i.map {
            guard let p = $0 else { return nil }
            return self.trackForPolygon[p]
        }
    }
    
    init(tracks: [Track]) {
        self.tracks = tracks
        hasSelection = selection.i.map { $0 != nil }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        disposables.append(selection.i.observe { value in
            self.updateForSelection()
        })
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
        lineView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        lineView.backgroundColor = .white
        lineView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(linePanned(sender:))))
        
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
        stackView.addArrangedSubview(lineView)
        view.backgroundColor = .white
        
        mapView.addAnnotation(draggedPointAnnotation)
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
        guard let track = selectedTrack.value ?? nil else { return }
        let normalizedLocation = sender.location(in: lineView).x / lineView.bounds.size.width
        let distance = Double(normalizedLocation) * track.distance
        let point = track.point(at: distance)!
        draggedPointAnnotation.coordinate = point.coordinate
        lineView.position = CGFloat(distance)
        if !mapView.annotations(in: mapView.visibleMapRect).contains(draggedPointAnnotation) {
            mapView.setCenter(point.coordinate, animated: true)
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
        if let s = selection.i.value ?? nil, possibilities.count > 1 && possibilities.contains(s) {
            
            selection.set(possibilities.lazy.sorted { $0.pointCount < $1.pointCount }.first(where: { $0 != s }))
        } else {
            selection.set(possibilities.first)
        }
    }
    
    func updateForSelection() {
        lineView.position = nil
        draggedPointAnnotation.coordinate = .init() // hide
        if let track = selectedTrack.value ?? nil {
            let profile = track.elevationProfile
            let elevations = profile.map { $0.elevation }
            let rect = CGRect(x: 0, y: elevations.min()!, width: profile.last!.distance.rounded(.up), height: elevations.max()!-elevations.min()!)
            lineView.pointsRect = rect
            lineView.points = profile.map { CGPoint(x: $0.distance, y: $0.elevation) }
            name.text = track.name
            let formatter = MKDistanceFormatter()
            totalDistance.text = formatter.string(fromDistance: track.distance)
            totalAscent.text = "↗ \(formatter.string(fromDistance: track.ascent))"
        } else {
            lineView.points = []
        }
//        for (line, renderer) in renderers {
//            if selection != nil && line != selection {
//                renderer.lineWidth = 1
//                renderer.alpha = 0.5
//            } else {
//                renderer.alpha = 1
//                renderer.lineWidth = 3
//            }
//        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let line = overlay as? MKPolygon {
            if let renderer = renderers[line] { return renderer.renderer }
            
            let isSelected: I<Bool> = selection.i.map { $0 == line }
            let shouldHighlight: I<Bool> = !hasSelection || isSelected
            let strokeColor: I<UIColor> = I(value: lines[line]!.uiColor)
            let alpha: I<CGFloat> = if_(shouldHighlight, then: I(value: 1), else: I(value: 0.5))
            let lineWidth: I<CGFloat> = if_(shouldHighlight, then: I(value: 3), else: I(value: 0.5))
            let renderer = PolygonRenderer(polygon: line, strokeColor: strokeColor, alpha: alpha, lineWidth: lineWidth)
            renderers[line] = renderer
            return renderer.renderer
        }
        return MKOverlayRenderer()
    }
}

