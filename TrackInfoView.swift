//
//  TrackInfoView.swift
//  Laufpark
//
//  Created by Chris Eidhof on 17.10.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

final class TrackInfoView: UIView {
    let panGestureRecognizer = UIPanGestureRecognizer()
    var track: Track? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    init() {
        super.init(frame: .zero)
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
        
        let profile = track.map { $0.elevationProfile } ?? []
        var (maxX, minY, maxY): (Double, Double, Double) = (0, .greatestFiniteMagnitude, 0)
        for value in profile {
            maxX = max(maxX, value.distance)
            minY = min(minY, value.elevation)
            maxY = max(maxY, value.elevation)
        }
        let points = profile.map { (CGFloat(($0.distance / maxX)), CGFloat(($0.elevation - minY) / (maxY - minY))) }
        
        let screenPoints = points.map { CGPoint(x: $0.0 * bounds.size.width, y: $0.1 * bounds.size.height) }
        UIColor.black.setStroke()
        if let start = screenPoints.first {
            context.move(to: start)
            for p in screenPoints.dropFirst() {
                context.addLine(to: p)
            }
            context.strokePath()
        }
    }
}
