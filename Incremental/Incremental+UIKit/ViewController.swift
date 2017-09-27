//
//  ViewController.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public typealias Constraint = (_ parent: UIView, _ child: UIView) -> NSLayoutConstraint

public func equalTop(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.topAnchor.constraint(equalTo: child.topAnchor)
}
public func equalLeading(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.leadingAnchor.constraint(equalTo: child.leadingAnchor)
}
public func equalTrailing(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.trailingAnchor.constraint(equalTo: child.trailingAnchor)
}

public func centerX(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.centerXAnchor.constraint(equalTo: child.centerXAnchor)
}

public func centerY(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.centerYAnchor.constraint(equalTo: child.centerYAnchor)
}



public func viewController<V: UIView>(rootView: IBox<V>, constraints: [Constraint] = []) -> IBox<UIViewController> {
    let vc = UIViewController()
    let box = IBox(vc)
    vc.view.addSubview(rootView.unbox)
    vc.view.backgroundColor = .white
    box.disposables.append(rootView)
    rootView.unbox.translatesAutoresizingMaskIntoConstraints = false
    for c in constraints {
        c(vc.view, rootView.unbox).isActive = true
    }
    return box
}

