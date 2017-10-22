//
//  Views.swift
//  Laufpark
//
//  Created by Chris Eidhof on 17.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import Incremental
import MapKit

enum Stylesheet {
    static let emphasis: I<UIFont> = I(constant: UIFont.boldSystemFont(ofSize: 17))
}


func trackInfoView(position: I<CGFloat?>, points: I<[LineView.Point]>, track: I<Track?>, darkMode: I<Bool>) -> (IBox<UIView>, location: I<CGFloat>) {
    let pannedLocation: Input<CGFloat> = Input(0)
    let result = IBox(UIView())

    let foregroundColor: I<UIColor> = if_(darkMode, then: I(constant: .white), else: I(constant: .black))
    let lv = lineView(position: position, points: points, strokeColor: foregroundColor)
    lv.unbox.backgroundColor = .clear
    lv.addGestureRecognizer(panGestureRecognizer { sender in
        let normalizedLocation = (sender.location(in: sender.view!).x /
            sender.view!.bounds.size.width).clamped(to: 0.0...1.0)
        pannedLocation.write(normalizedLocation)
    })
 
    let formatter = MKDistanceFormatter()
    let formattedDistance = track.map { track in
        track.map { formatter.string(fromDistance: $0.distance) }
        } ?? ""
    let formattedAscent = track.map { track in
        track.map { "↗ \(formatter.string(fromDistance: $0.ascent))" }
        } ?? ""
    //let name = label(text: track.map { $0?.name ?? "" }, textColor: foregroundColor.map { $0 })
    let totalDistance = label(text: formattedDistance, textColor: foregroundColor.map { $0 }, font: Stylesheet.emphasis)
    let totalAscent = label(text: formattedAscent, textColor: foregroundColor.map { $0 }, font: Stylesheet.emphasis)
    let spacer = IBox(UILabel())
    
    // Track information
    let trackInfo = IBox<UIStackView>(arrangedSubviews: [totalDistance, totalAscent, spacer], axis: .horizontal)
    trackInfo.unbox.distribution = .equalCentering
    trackInfo.unbox.spacing = 10
    
    result.addSubview(trackInfo, constraints: [equal(\.leadingAnchor), equal(\.trailingAnchor), equal(\.topAnchor)])
    result.addSubview(lv, constraints: [equal(\.leadingAnchor), equal(\.trailingAnchor), equal(\.bottomAnchor), equalTo(constant: 20, \.heightAnchor)])
    lv.unbox.topAnchor.constraint(equalTo: trackInfo.unbox.bottomAnchor).isActive = true
        
    return (result, pannedLocation.i)
}

func effectView(effect: I<UIVisualEffect>) -> IBox<UIVisualEffectView> {
    let view = UIVisualEffectView(effect: nil)
    let result = IBox(view)
    result.observe(value: effect, onChange: { view, value in
        UIView.animate(withDuration: 0.2) {
            view.effect = value
        }
    })
    return result
}

extension MKPointAnnotation {
    convenience init(coordinate: CLLocationCoordinate2D, title: String) {
        self.init()
        self.coordinate = coordinate
        self.title = title
    }
}

func trailNumber(track: I<Track>) -> IBox<UIView> {
    let diameter: CGFloat = 42
    let circle = UIView(frame: .init(origin: .zero, size: CGSize(width: diameter, height: diameter)))
    circle.layer.cornerRadius = diameter/2
    circle.layer.masksToBounds = true
    circle.translatesAutoresizingMaskIntoConstraints = false
    circle.widthAnchor.constraint(equalToConstant: diameter).isActive = true
    circle.heightAnchor.constraint(equalToConstant: diameter).isActive = true
    
    let backgroundColor = track.map { $0.color.uiColor }
    let result = IBox(circle)
    result.bind(backgroundColor, to: \.backgroundColor)

    
    let numberLabel = label(text: track.map { $0.numbers }, backgroundColor: backgroundColor.map { $0 }, textColor: I(constant: .white), font: I(constant: UIFont.boldSystemFont(ofSize: 17)) )
    result.addSubview(numberLabel, constraints: [
        equal(\.centerXAnchor), equal(\.centerYAnchor)])
    
    return result
}

func buildMapView() -> IBox<MKMapView> {
    let box = IBox(MKMapView())
    let view = box.unbox
    view.showsCompass = true
    view.showsScale = true
    view.showsUserLocation = true
    view.mapType = .standard
    view.isRotateEnabled = false
    view.isPitchEnabled = false
    return box
}

func polygonRenderer(polygon: MKPolygon, strokeColor: I<UIColor>, fillColor: I<UIColor?>, alpha: I<CGFloat>, lineWidth: I<CGFloat>) -> IBox<MKPolygonRenderer> {
    let renderer = MKPolygonRenderer(polygon: polygon)
    let box = IBox(renderer)
    box.bind(strokeColor, to: \.strokeColor)
    box.bind(alpha, to : \.alpha)
    box.bind(lineWidth, to: \.lineWidth)
    box.bind(fillColor, to: \.fillColor)
    return box
}

func annotation(location: I<CLLocationCoordinate2D>) -> IBox<MKPointAnnotation> {
    let result = IBox(MKPointAnnotation())
    result.bind(location, to: \.coordinate)
    return result
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

func lineView(position: I<CGFloat?>, points: I<[LineView.Point]>, strokeColor: I<UIColor>) -> IBox<LineView> {
    let box = IBox(LineView())
    box.bind(position, to: \LineView.position)
    box.bind(points, to: \.points)
    box.bind(strokeColor, to: \.strokeColor)
    return box
}
