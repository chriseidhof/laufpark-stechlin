//
//  Constraints.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public typealias Constraint = (_ parent: UIView, _ child: UIView) -> IBox<NSLayoutConstraint>

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, to: KeyPath<UIView, Anchor>, constant: I<CGFloat> = I(constant: 0)) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return { parent, child in
         let result = IBox(parent[keyPath: keyPath].constraint(equalTo: child[keyPath: keyPath]))
         result.bindConstant(constant, view: parent)
         return result
    }
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, to: KeyPath<UIView, Anchor>, constant: CGFloat) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: to, constant: I(constant: constant))
}

public func sizeToParent(inset constant: I<CGFloat> = I(constant: 0)) -> [Constraint] {
    return [equal(\.leadingAnchor, constant: -constant),
            equal(\.trailingAnchor, constant: constant),
            equal(\.topAnchor, constant: -constant),
            equal(\.bottomAnchor, constant: constant)]
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, constant: I<CGFloat> = I(constant: 0)) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: keyPath, constant: constant)
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<UIView, Anchor>, _ constant: CGFloat) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: keyPath, constant: I(constant: constant))
}


public func equalTo(constant: I<CGFloat> = I(constant: 0), _ keyPath: KeyPath<UIView, NSLayoutDimension>) -> Constraint  {
    return { parent, child in
        let constraint = IBox(child[keyPath: keyPath].constraint(equalToConstant: 0))
        constraint.bindConstant(constant, view: parent)
        return constraint
    }
}

extension IBox where V: NSLayoutConstraint {
    public func bindConstant(_ i: I<CGFloat>, view: UIView, animated: CGFloat = 0.2) {
        disposables.append((i).observe { [unowned self] newValue in
            self.unbox.constant = newValue
            UIView.animate(withDuration: 0.2) {
                view.layoutIfNeeded()
            }
        })
    }
}
