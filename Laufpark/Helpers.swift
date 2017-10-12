//
//  Helpers.swift
//  Laufpark
//
//  Created by Chris Eidhof on 18.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

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

extension CGContext {
    func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor) {
        move(to: start)
        addLine(to: end)
        color.setStroke()
        strokePath()
    }
}

extension Comparable {
    func clamped(to: ClosedRange<Self>) -> Self {
        if self < to.lowerBound { return to.lowerBound }
        if self > to.upperBound { return to.upperBound }
        return self
    }
}


func time(name: StaticString = #function, line: Int = #line, _ f: () -> ()) {
    let startTime = DispatchTime.now()
    f()
    let endTime = DispatchTime.now()
    let diff = (endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
    print("\(name) (line \(line)): \(diff)")
}
