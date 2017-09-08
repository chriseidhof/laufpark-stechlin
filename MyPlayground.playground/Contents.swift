//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport

final class LineView: UIView {
    var pointsRect: CGRect {
        didSet { self.setNeedsDisplay() }
    }
    var points: [CGPoint] {
        didSet { self.setNeedsDisplay() }
    }
    
    var horizontalTick: CGFloat? = 5
    var tickColor: UIColor = .lightGray
    
    init(pointsRect: CGRect, points: [CGPoint]) {
        self.pointsRect = pointsRect
        self.points = points
        super.init(frame: .zero)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setLineWidth(1)
        UIColor.black.setStroke()
        
        context.translateBy(x: 0, y: bounds.size.height)
        let scaleX = bounds.size.width/pointsRect.size.width
        let scaleY = bounds.size.height/pointsRect.size.height
        
        
        var currentTick = horizontalTick
        while currentTick < bounds.size.width {
            context.strokeLineSegments(between: [
                CGPoint(x: currentTick, y: 0),
                CGPoint(x: currentTick, y: bounds.size.height)
            ])
        }
        
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

let graphView = LineView(pointsRect: CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 150)), points: [
        CGPoint(x: 10, y: 10),
        CGPoint(x: 30, y: 40),
        CGPoint(x: 50, y: 100),
        CGPoint(x: 60, y: 145)
    ])
graphView.backgroundColor = .green
graphView.frame = CGRect(origin: .zero, size: CGSize(width: 300, height: 100))
PlaygroundPage.current.liveView = graphView
1+1
