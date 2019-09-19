//
//  LineView.swift
//  Laufpark
//
//  Created by Chris Eidhof on 08.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import MapKit

extension CGContext {
    func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor) {
        color.setStroke()
        move(to: start)
        addLine(to: end)
        strokePath()
    }
}

final class LineView: UIView {
    struct Point: Equatable {
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
    
    var horizontalTick: CGFloat {
        // distanceFormatter.units doesn't return the right value...
        return distanceFormatter.locale.usesMetricSystem ? 5000 : 4828.03
    }
    var tickColor: UIColor = UIColor.gray.withAlphaComponent(0.3) { didSet { setNeedsDisplay() } }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        setNeedsDisplay()
    }
    
    func recomputePointsRect() {
        var (minY, maxY, maxX): (CGFloat, CGFloat, CGFloat) = (.greatestFiniteMagnitude, 0, 0)
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


        let labelPadding: CGFloat = 20
        
        let scaleX = bounds.size.width/_pointsRect.size.width
        let scaleY = (bounds.size.height-labelPadding)/_pointsRect.size.height



        // drawing ticks
        let cgTickWidth = horizontalTick * scaleX
        let ticks: [CGFloat] = Array(sequence(state: cgTickWidth, next: { (currentTick: inout CGFloat) in
            defer { currentTick += cgTickWidth }
            guard currentTick < self.bounds.size.width else { return nil }
            return currentTick
        }))

        let attributes: [NSAttributedStringKey : Any] = [
            .foregroundColor: strokeColor,
            .font: Stylesheet.smallFont
        ]
        
        for tick in ticks {
            let start = CGPoint(x: tick, y: 0)
            let end = CGPoint(x: tick, y: bounds.size.height-labelPadding)
            context.setLineWidth(1)
            context.drawLine(from: start, to: end, color: tickColor)

            let text = distanceFormatter.string(fromDistance: CLLocationDistance((tick/scaleX))) as NSString
            let width = text.size(withAttributes: attributes).width
            guard (tick + width/2) < bounds.width else { continue }
            (text as NSString).draw(at: CGPoint(x: tick - (width/2), y: bounds.size.height-labelPadding + 5), withAttributes: attributes)
        }
        
        // drawing the "cursor"
        // todo this should be a separate uiview so that we don't need to redraw all the time
        if let position = position {
            let start = CGPoint(x: position*scaleX, y: 0)
            let end = CGPoint(x: position*scaleX, y: bounds.size.height-labelPadding)
            context.move(to: start)
            context.addLine(to: end)
            positionColor.setStroke()
            context.strokePath()
        }
        
        context.saveGState()
        context.translateBy(x: 0, y: bounds.size.height-labelPadding)
        context.scaleBy(x: 1, y: -1)
        context.setLineWidth(strokeWidth)
        strokeColor.setStroke()
        let points = self.points.map {
            CGPoint(x: (CGFloat($0.x)-_pointsRect.origin.x) * scaleX, y: (CGFloat($0.y)-_pointsRect.origin.y) * scaleY)
        }
        guard let start = points.first else { return }
        context.move(to: start)
        for p in points.dropFirst() {
            context.addLine(to: p)
        }
        context.strokePath()
        context.restoreGState()
    }
}
