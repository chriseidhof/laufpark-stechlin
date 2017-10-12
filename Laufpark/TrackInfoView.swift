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

    private var strokeWidth: CGFloat = 1 { didSet { setNeedsDisplay() }}
    private var strokeColor: UIColor = .black { didSet { setNeedsDisplay() }}
    private var positionColor: UIColor = .red { didSet { setNeedsDisplay() }}
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
        guard !self.points.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.translateBy(x: 0, y: bounds.size.height)
        context.scaleBy(x: 1, y: -1)
        
        if let position = position {
            let start = CGPoint(x: position*bounds.size.width, y: 0)
            let end = CGPoint(x: position*bounds.size.width, y: -bounds.size.height)
            context.drawLine(from: start, to: end, color: positionColor)
        }
        
        context.setLineWidth(strokeWidth)
        strokeColor.setStroke()
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
        guard !profile.isEmpty else {
            points = []
            return
        }
        let x = profile.map { CGFloat($0.distance) }
        let y = profile.map { CGFloat($0.elevation) }
        let maxX = x.max()!
        let minY = y.min()!
        let maxY = y.max()!
        let normalizedX = x.map { $0 / maxX }
        let normalizedY = y.map { ($0 - minY) / (maxY - minY) }
        points = Array(zip(normalizedX, normalizedY))
    }
}

