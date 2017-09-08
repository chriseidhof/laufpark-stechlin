//
//  ViewController.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, MKMapViewDelegate {
    let tracks: [Track]
    let mapView = MKMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: MKPolygonRenderer] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    let lineView = LineView()
    var stackView: UIStackView = UIStackView(arrangedSubviews: [])
    
    var selection: MKPolygon? {
        didSet {
            updateForSelection()
            if let t = selectedTrack {
                print(t.name)
                print("\(t.distance / 1000) km")
                let a = t.ascent
                print("ascent: \(a)m")
            }
        }
    }
    
    var selectedTrack: Track? {
        return selection.flatMap { trackForPolygon[$0] }
    }
    
    init(tracks: [Track]) {
        self.tracks = tracks
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        view.addSubview(stackView)
        lineView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        lineView.backgroundColor = .white
        stackView.addArrangedSubview(mapView)
        stackView.addArrangedSubview(lineView)
        stackView.distribution = .fill
        stackView.axis = .vertical
        stackView.backgroundColor = .green
        stackView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        tracks.forEach {
            let line = $0.line
            mapView.add(line)
            lines[line] = $0.color
            trackForPolygon[line] = $0
        }
        
        stackView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        stackView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        stackView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.mapType = .hybrid
        mapView.setVisibleMapRect(MKMapRect(origin: MKMapPoint(x: 143758507.60971117, y: 86968700.835495561), size: MKMapSize(width: 437860.61378830671, height: 749836.27541357279)), edgePadding: UIEdgeInsetsMake(10, 10, 10, 10), animated: true)
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(mapTapped(sender:))))
    }
    
    @objc func mapTapped(sender: UITapGestureRecognizer) {
        let point = sender.location(ofTouch: 0, in: mapView)
        let mapPoint = MKMapPointForCoordinate(mapView.convert(point, toCoordinateFrom: mapView))
        let newSelection = lines.keys.first { line in
            let renderer = renderers[line]!
            let point = renderer.point(for: mapPoint)
            return renderer.path.contains(point)
        }
        if selection == newSelection {
            selection = nil
        } else {
            selection = newSelection
        }
    }
    
    func updateForSelection() {
        if let track = selectedTrack {
            let profile = track.elevationProfile
            let elevations = profile.map { $0.elevation }
            let rect = CGRect(x: 0, y: elevations.min()!, width: profile.last!.distance.rounded(.up), height: elevations.max()!-elevations.min()!)
            lineView.pointsRect = rect
            lineView.points = profile.map { CGPoint(x: $0.distance, y: $0.elevation) }
        } else {
            lineView.points = []
        }
        for (line, renderer) in renderers {
            if selection != nil && line != selection {
                renderer.lineWidth = 1
                renderer.alpha = 0.5
            } else {
                renderer.alpha = 1
                renderer.lineWidth = 3
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let line = overlay as? MKPolygon {
            if let renderer = renderers[line] { return renderer }
            let renderer = MKPolygonRenderer(polygon: line)
            renderer.strokeColor = lines[line]!.uiColor
            renderer.lineWidth = 2
            renderers[line] = renderer
            return renderer
        }
        return MKOverlayRenderer()
    }
}

