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
    
    static let smallFont = UIFont.systemFont(ofSize: 10)
    
    static let blue: UIColor = UIColor(red: 13.0/255, green: 107.0/255, blue: 181.0/255, alpha: 1)
    
    static let regularInset: CGFloat = 10

    static let dampingAnimation: Animation = { parent, _ in
        UIViewPropertyAnimator(duration: 0.2, dampingRatio: 0.6) {
            parent.layoutIfNeeded()
        }.startAnimation()
    }
}

extension LineView.Point {
    func distanceTo(segment: (LineView.Point, LineView.Point)) -> Double {
        let a = x - segment.0.x
        let b = y - segment.0.y
        let c = segment.1.x - segment.0.x
        let d = segment.1.x - segment.0.x
        
        let dot = a * c + b * d
        let lenSq = c*c + d*d
        let param = dot / lenSq
        
        let p: LineView.Point
        if param < 0 || (segment.0 == segment.1) {
            p = segment.0
        } else if param > 1 {
            p = segment.1
        } else {
            p = LineView.Point(x: segment.0.x + param * c, y: segment.0.y + param * d)
        }
        
        let dx = x - p.x
        let dy = y - p.y
        return (dx*dx + dy*dy).squareRoot()        
    }
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
    result.addSubview(lv.cast, constraints: [equal(\.leadingAnchor), equal(\.trailingAnchor), equal(\.bottomAnchor), equalTo(constant: I(constant: 100), \.heightAnchor)])
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

func trackNumberView(_ track: I<Track>) -> IBox<UIView> {
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

    
    let numberLabel = label(text: track.map { $0.numbers }, backgroundColor: backgroundColor.map { $0 }, textColor: track.map { $0.color.textColor }, font: Stylesheet.emphasis)
    result.addSubview(numberLabel, constraints: [
        equal(\.centerXAnchor), equal(\.centerYAnchor)])
    
    return result
}

extension CLLocationCoordinate2D: Equatable {
    public static func ==(lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

func lineView(position: I<CGFloat?>, points: I<[LineView.Point]>, strokeColor: I<UIColor>) -> IBox<LineView> {
    let box = IBox(LineView())
    box.bind(position, to: \.position)
    box.bind(points, to: \.points)
    box.bind(strokeColor, to: \.strokeColor)
    return box
}
