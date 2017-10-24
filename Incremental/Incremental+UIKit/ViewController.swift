//
//  ViewController.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public func viewController<V: UIView>(rootView: IBox<V>, constraints: [Constraint] = []) -> IBox<UIViewController> {
    let vc = UIViewController()
    let box = IBox(vc)
    vc.view.addSubview(rootView.unbox)
    vc.view.backgroundColor = .white
    box.disposables.append(rootView)
    rootView.unbox.translatesAutoresizingMaskIntoConstraints = false
    
    let evaluatedConstraints = constraints.map { $0(vc.view, rootView.unbox) }
    NSLayoutConstraint.activate(evaluatedConstraints.map { $0.unbox })
    box.disposables.append(evaluatedConstraints)
    return box
}

extension IBox where V: UIViewController {
    public func setRightBarButtonItems(_ value: [IBox<UIBarButtonItem>]) {
        let existing = unbox.navigationItem.rightBarButtonItems ?? []
        precondition(existing == [])
        for b in value {
            disposables.append(b)
        }
        unbox.navigationItem.rightBarButtonItems = value.map { $0.unbox }
    }
}
