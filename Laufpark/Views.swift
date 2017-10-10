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

protocol TrackInfoViewDelegate: class {
    func changedPosition(to position: CGFloat?)
}

final class TrackInfoView: UIView {
    private var lineView = buildLineView(position: nil, points: [], strokeColor: .black)
    private var nameLabel = UILabel()
    private var distanceLabel = UILabel()
    private var ascentLabel = UILabel()
    
    weak var delegate: TrackInfoViewDelegate?
    var track: Track? {
        didSet {
            updateLineView()
            updateTrackInfo()
            position = nil
        }
    }
    var position: CGFloat? {
        didSet {
            lineView.position = position
        }
    }
    
    func updateLineView() {
        let profile = track.map { $0.elevationProfile } ?? []
        lineView.points = profile.map { LineView.Point(x: $0.distance, y: $0.elevation) }
    }
    
    func updateTrackInfo() {
        let formatter = MKDistanceFormatter()
        let formattedDistance = track.map { formatter.string(fromDistance: $0.distance) } ?? ""
        let formattedAscent = track.map { "↗ \(formatter.string(fromDistance: $0.ascent))" } ?? ""
        nameLabel.text = track?.name ?? ""
        distanceLabel.text = formattedDistance
        ascentLabel.text = formattedAscent
    }
    
    init() {
        super.init(frame: .zero)
        
        // Lineview
        lineView.backgroundColor = .clear
        lineView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(linePanned(sender:))))
        
        // Track information
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        ascentLabel.translatesAutoresizingMaskIntoConstraints = false
        let trackInfo = UIStackView(arrangedSubviews: [nameLabel, distanceLabel, ascentLabel])
        trackInfo.axis = .horizontal
        trackInfo.distribution = .equalCentering
        trackInfo.spacing = 10
        
        let blurredView = UIVisualEffectView(effect: nil)
        blurredView.translatesAutoresizingMaskIntoConstraints = false
        blurredView.effect = UIBlurEffect(style: .light)
        
        let stackView = UIStackView(arrangedSubviews: [trackInfo, lineView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 5
        
        blurredView.contentView.addSubview(stackView)
        stackView.addConstraintsToSizeToParent(spacing: 10)

        addSubview(blurredView)
        blurredView.addConstraintsToSizeToParent()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func linePanned(sender: UIPanGestureRecognizer) {
        let normalizedLocation = (sender.location(in: lineView).x / lineView.bounds.size.width).clamped(to: 0.0...1.0)
        delegate?.changedPosition(to: normalizedLocation)
    }
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




func buildMapView() -> MKMapView {
    let view = MKMapView()
    view.showsCompass = true
    view.showsScale = true
    view.showsUserLocation = true
    view.mapType = .standard
    view.isRotateEnabled = false
    view.isPitchEnabled = false
    return view
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

func buildLineView(position: CGFloat?, points: [LineView.Point], strokeColor: UIColor) -> LineView {
    let view = LineView()
    view.position = position
    view.points = points
    view.strokeColor = strokeColor
    return view
}
