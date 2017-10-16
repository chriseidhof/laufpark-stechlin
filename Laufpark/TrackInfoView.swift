//
//  TrackInfoView.swift
//  Laufpark
//
//  Created by Florian Kugler on 12-10-2017.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

final class TrackInfoView: UIView {
    private var lineView = LineView()
    private var nameLabel = UILabel()
    private var distanceLabel = UILabel()
    private var ascentLabel = UILabel()
    private let blurredView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

    var darkMode = false {
        didSet {
            blurredView.effect = UIBlurEffect(style: darkMode ? .dark : .light)
            lineView.strokeColor = darkMode ? .white : .black
            [nameLabel, distanceLabel, ascentLabel].forEach { $0.textColor = lineView.strokeColor }
        }
    }
    
    let panGestureRecognizer = UIPanGestureRecognizer()
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
        lineView.points = profile.map { (x: $0.distance, y: $0.elevation) }
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
        
        lineView.backgroundColor = .clear
        lineView.addGestureRecognizer(panGestureRecognizer)
        
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        ascentLabel.translatesAutoresizingMaskIntoConstraints = false
        let trackInfo = UIStackView(arrangedSubviews: [nameLabel, distanceLabel, ascentLabel])
        trackInfo.axis = .horizontal
        trackInfo.distribution = .equalCentering
        trackInfo.spacing = 10
        
        blurredView.translatesAutoresizingMaskIntoConstraints = false
        
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
}


