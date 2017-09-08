//
//  ViewController.swift
//  Laufpark
//
//  Created by Chris Eidhof on 07.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

extension UIColor {
    convenience init(r: Int, g: Int, b: Int) {
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}

extension Color {
    var uiColor: UIColor {
        switch self {
        case .red: 
           return UIColor(r: 255, g: 0, b: 0)
        case .turquoise:
            return UIColor(r: 0, g: 159, b: 159)
        case .brightGreen:
            return UIColor(r: 104, g: 195, b: 12)
        case .violet:
            return UIColor(r: 174, g: 165, b: 213)
        case .purple:
            return UIColor(r: 135, g: 27, b: 138)
        case .green:
            return UIColor(r: 0, g: 132, b: 70)
        case .beige:
            return UIColor(r: 227, g: 177, b: 151)
        case .blue:
            return UIColor(r: 0, g: 92, b: 181)
        case .brown:
            return UIColor(r: 0, g: 92, b: 181)
        case .yellow:
            return UIColor(r: 255, g: 244, b: 0)
        case .gray:
            return UIColor(r: 174, g: 165, b: 213)
        case .lightBlue:
            return UIColor(r: 0, g: 166, b: 198)
        case .lightBrown:
            return UIColor(r: 190, g: 135, b: 90)
        case .orange:
            return UIColor(r: 255, g: 122, b: 36)
        case .pink:
            return UIColor(r: 255, g: 0, b: 94)
        case .lightPink:
            return UIColor(r: 255, g: 122, b: 183)
        }
    }
}

extension Track {
    var line: MKPolygon {
        var coordinates = self.coordinates.map { $0.0 }
        let result = MKPolygon(coordinates: &coordinates, count: coordinates.count)
        return result
    }
    
    var name: String {
        return "\(color.name) \(number)"
    }
    
    var ascentAndDescent: (Double, Double) {
        var ascent = 0.0
        var descent = 0.0
        var previous = self.coordinates.first!.elevation
        for x in self.coordinates {
            let diff = previous - x.elevation
            if diff > 0 {
                ascent += diff
            } else {
                descent += diff
            }
            previous = x.elevation
        }
        return (ascent, descent)
    }
}

class ViewController: UIViewController, MKMapViewDelegate {
    let tracks: [Track]
    let mapView = MKMapView()
    var lines: [MKPolygon:Color] = [:]
    var renderers: [MKPolygon: MKPolygonRenderer] = [:]
    var trackForPolygon: [MKPolygon:Track] = [:]
    
    var selection: MKPolygon? {
        didSet {
            updateForSelection()
            if let t = selectedTrack {
                print(t.name)
                print("\(t.distance / 1000) km")
                let (a,d) = t.ascentAndDescent
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
        self.view.addSubview(mapView)
        mapView.delegate = self
        tracks.forEach {
            let line = $0.line
            mapView.add(line)
            lines[line] = $0.color
            trackForPolygon[line] = $0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        mapView.frame = view.bounds
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

