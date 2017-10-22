//
//  LineView.swift
//  Laufpark
//
//  Created by Chris Eidhof on 08.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

final class LineView: UIView {
    struct Point: Equatable {
        static func ==(lhs: LineView.Point, rhs: LineView.Point) -> Bool {
            return lhs.x == rhs.x && lhs.y == rhs.y
        }

        var x: Double
        var y: Double
    }

    var strokeWidth: CGFloat = 1 { didSet { setNeedsDisplay() }}
    var strokeColor: UIColor = .black { didSet { setNeedsDisplay() }}
    var position: CGFloat? = nil { didSet { setNeedsDisplay() }}
    var positionColor: UIColor = .red { didSet { setNeedsDisplay() }}
    let distanceFormatter: MKDistanceFormatter = {
        let result = MKDistanceFormatter()
        result.unitStyle = .abbreviated
        return result
    }()
    
    private var _pointsRect: CGRect = .zero

    var points: [Point] = [] {
        didSet {
            recomputePointsRect()
            setNeedsDisplay()
        }
    }
    
    var horizontalTick: CGFloat? {
        return distanceFormatter.units == .metric ? 5000 : 4828.03
    }
    var tickColor: UIColor = UIColor.gray.withAlphaComponent(0.3) { didSet { setNeedsDisplay() } }
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            setNeedsDisplay()
        }
    }
    
    func recomputePointsRect() {
        var (minY, maxY, maxX): (CGFloat, CGFloat, CGFloat) = (100000, 0, 0)
        for p in points {
            minY = min(minY, CGFloat(p.y))
            maxY = max(maxY, CGFloat(p.y))
            maxX = max(maxX, CGFloat(p.x))
        }
        
        _pointsRect = CGRect(x: 0, y: minY, width: maxX.rounded(.up), height: maxY-minY)
    }
    
    override func draw(_ rect: CGRect) {
        guard !self.points.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.translateBy(x: 0, y: bounds.size.height)
        
        let scaleX = bounds.size.width/_pointsRect.size.width
        let scaleY = bounds.size.height/_pointsRect.size.height
        
        if let tickWidth = horizontalTick {
            let cgTickWidth = tickWidth * scaleX
            context.setLineWidth(1)
            var currentTick = cgTickWidth
            while currentTick < bounds.size.width {
                let start = CGPoint(x: currentTick, y: 0)
                context.move(to: start)
                context.addLine(to: CGPoint(x: currentTick, y: -bounds.size.height))
                tickColor.setStroke()
                context.strokePath()
                let text = distanceFormatter.string(fromDistance: CLLocationDistance((currentTick/scaleX).rounded()))
                (text as NSString).draw(at: CGPoint(x: currentTick + 5, y: -15), withAttributes: [
                    .foregroundColor: strokeColor,
                    .font: UIFont.systemFont(ofSize: 12)
                    ])
                currentTick += cgTickWidth
            }
        }
        
        if let position = position {
            let start = CGPoint(x: position*scaleX, y: 0)
            let end = CGPoint(x: position*scaleX, y: -bounds.size.height)
            context.move(to: start)
            context.addLine(to: end)
            positionColor.setStroke()
            context.strokePath()
        }
        
        context.setLineWidth(strokeWidth)
        strokeColor.setStroke()
        let points = self.points.map {
            CGPoint(x: (CGFloat($0.x)-_pointsRect.origin.x) * scaleX, y: (CGFloat($0.y)-_pointsRect.origin.y) * -scaleY)
        }
        guard let start = points.first else { return }
        context.move(to: start)
        for p in points.dropFirst() {
            context.addLine(to: p)
        }
        context.strokePath()
    }
}
