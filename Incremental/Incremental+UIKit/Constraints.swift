//
//  Constraints.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation



public typealias Constraint = (_ parent: IncView, _ child: IncView) -> IBox<NSLayoutConstraint>

public typealias Animation = (_ parent: IncView, _ child: IncView) -> ()

public let noAnimation: Animation = { _,_ in () }

public func equal<Anchor, Axis>(_ keyPath: KeyPath<IncView, Anchor>, to: KeyPath<IncView, Anchor>, constant: I<CGFloat> = I(constant: 0), animation: @escaping Animation = noAnimation) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return { parent, child in
        let result = IBox(parent[keyPath: keyPath].constraint(equalTo: child[keyPath: keyPath]))
        result.bindConstant(constant, animation: { animation(parent, child) } )
        return result
    }
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<IncView, Anchor>, to: KeyPath<IncView, Anchor>, constant: CGFloat, animation: @escaping Animation = noAnimation) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: to, constant: I(constant: constant), animation: animation)
}

public func sizeToParent(inset constant: I<CGFloat> = I(constant: 0), animation: @escaping Animation = noAnimation) -> [Constraint] {
    return [equal(\.leadingAnchor, constant: -constant, animation: animation),
            equal(\.trailingAnchor, constant: constant, animation: animation),
            equal(\.topAnchor, constant: -constant, animation: animation),
            equal(\.bottomAnchor, constant: constant, animation: animation)]
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<IncView, Anchor>, constant: I<CGFloat> = I(constant: 0), animation: @escaping Animation = noAnimation) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: keyPath, constant: constant, animation: animation)
}

public func equal<Anchor, Axis>(_ keyPath: KeyPath<IncView, Anchor>, _ constant: CGFloat, animation: @escaping Animation = noAnimation) -> Constraint where Anchor: NSLayoutAnchor<Axis> {
    return equal(keyPath, to: keyPath, constant: I(constant: constant), animation: animation)
}


public func equalTo(constant: I<CGFloat> = I(constant: 0), _ keyPath: KeyPath<IncView, NSLayoutDimension>, animation:  @escaping Animation = noAnimation) -> Constraint  {
    return { parent, child in
        let constraint = IBox(child[keyPath: keyPath].constraint(equalToConstant: 0))
        constraint.bindConstant(constant, animation: { animation(parent, child) } )
        return constraint
    }
}

extension IBox where V: NSLayoutConstraint {
    public func bindConstant(_ i: I<CGFloat>, animation: @escaping () -> ()) {
        disposables.append((i).observe { [unowned self] newValue in
            self.unbox.constant = newValue
            animation()
        })
    }
}
