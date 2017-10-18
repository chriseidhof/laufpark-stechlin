//
//  Constraints.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public typealias Constraint = (_ parent: UIView, _ child: UIView) -> NSLayoutConstraint

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, to: KeyPath<UIView, Anchor>, constant: CGFloat = 0) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return { parent, child in
         parent[keyPath: keyPath].constraint(equalTo: child[keyPath: keyPath], constant: constant)
    }
}

public func sizeToParent(inset constant: CGFloat = 0) -> [Constraint] {
    return [equal(\.leadingAnchor, constant: -constant),
            equal(\.trailingAnchor, constant: constant),
            equal(\.topAnchor, constant: -constant),
            equal(\.bottomAnchor, constant: constant)]
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, constant: CGFloat = 0) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: keyPath, constant: constant)
}
