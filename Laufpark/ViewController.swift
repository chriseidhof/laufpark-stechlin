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
    var line: MKPolyline {
        var coordinates = self.coordinates
        let result = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        return result
    }
}

class ViewController: UIViewController, MKMapViewDelegate {
    let tracks: [Track]
    let mapView = MKMapView()
    var lines: [MKPolyline:UIColor] = [:]
    
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
            lines[line] = $0.color.uiColor
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        mapView.frame = view.bounds
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let line = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: line)
            renderer.strokeColor = lines[line]!
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
}

