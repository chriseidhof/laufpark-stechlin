//
//  LineView.swift
//  Laufpark
//
//  Created by Chris Eidhof on 08.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

final class LineView: UIView {
    var strokeWidth: CGFloat = 1 { didSet { setNeedsDisplay() }}
    var strokeColor: UIColor = .black { didSet { setNeedsDisplay() }}
    
    var pointsRect: CGRect = .zero {
        didSet { setNeedsDisplay() }
    }
    var points: [CGPoint] = [] {
        didSet { setNeedsDisplay() }
    }
    
    var horizontalTick: CGFloat? = 5000 { didSet { setNeedsDisplay() } }
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
    
    
    
    override func draw(_ rect: CGRect) {
        guard !self.points.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.translateBy(x: 0, y: bounds.size.height)
        
        let scaleX = bounds.size.width/pointsRect.size.width
        let scaleY = bounds.size.height/pointsRect.size.height

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
                let km = Int((currentTick/scaleX)/1000)
                ("\(km) km" as NSString).draw(at: CGPoint(x: currentTick + 5, y: -15), withAttributes: [
                    .foregroundColor: UIColor.black,
                    .font: UIFont.systemFont(ofSize: 12)
                    ])
                currentTick += cgTickWidth
            }
        }
        
        context.setLineWidth(strokeWidth)
        strokeColor.setStroke()
        let points = self.points.map {
            CGPoint(x: ($0.x-pointsRect.origin.x) * scaleX, y: ($0.y-pointsRect.origin.y) * -scaleY)
        }
        guard let start = points.first else { return }
        context.move(to: start)
        for p in points.dropFirst() {
            context.addLine(to: p)
        }
        context.strokePath()
    }
}
