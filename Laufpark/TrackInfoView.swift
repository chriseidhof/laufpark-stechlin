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
    let panGestureRecognizer = UIPanGestureRecognizer()
    var track: Track? {
        didSet {
            updatePoints()
            position = nil
            setNeedsDisplay()
        }
    }
    var position: CGFloat? {
        didSet {
            setNeedsDisplay()
        }
    }

    private var points: [(x: CGFloat, y: CGFloat)] = []
    
    init() {
        super.init(frame: .zero)
        backgroundColor = .white
        addGestureRecognizer(panGestureRecognizer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)
        
        if let position = position {
            let start = CGPoint(x: position*bounds.size.width, y: 0)
            let end = CGPoint(x: position*bounds.size.width, y: bounds.size.height)
            context.drawLine(from: start, to: end, color: .red)
        }
        
        UIColor.black.setStroke()
        let points = self.points.map { CGPoint(x: $0.x * bounds.size.width, y: $0.y * bounds.size.height) }
        guard let start = points.first else { return }
        context.move(to: start)
        for p in points.dropFirst() {
            context.addLine(to: p)
        }
        context.strokePath()
    }

    private func updatePoints() {
        let profile = track.map { $0.elevationProfile } ?? []
        var (maxX, minY, maxY): (Double, Double, Double) = (0, .greatestFiniteMagnitude, 0)
        for value in profile {
            maxX = max(maxX, value.distance)
            minY = min(minY, value.elevation)
            maxY = max(maxY, value.elevation)
        }
        points = profile.map { (CGFloat($0.distance / maxX), CGFloat(($0.elevation - minY) / (maxY - minY))) }
    }
}

