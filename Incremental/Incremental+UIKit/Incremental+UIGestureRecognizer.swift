//
//  Incremental+UIKit.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

// todo dry
public func panGestureRecognizer(_ panned: @escaping (UIPanGestureRecognizer) -> ()) -> IBox<UIPanGestureRecognizer> {
    let recognizer = UIPanGestureRecognizer()
    let targetAction = TargetAction { panned(recognizer) }
    recognizer.addTarget(targetAction, action: #selector(TargetAction.action(_:)))
    let result = IBox(recognizer)
    result.disposables.append(targetAction)
    return result
}

public func tapGestureRecognizer(_ tapped: @escaping (UITapGestureRecognizer) -> ()) -> IBox<UITapGestureRecognizer> {
    let recognizer = UITapGestureRecognizer()
    let targetAction = TargetAction { tapped(recognizer) }
    recognizer.addTarget(targetAction, action: #selector(TargetAction.action(_:)))
    let result = IBox(recognizer)
    result.disposables.append(targetAction)
    return result
}

extension IBox where V: UIView {
    public func addGestureRecognizer<G: UIGestureRecognizer>(_ gestureRecognizer: IBox<G>) {
        self.unbox.addGestureRecognizer(gestureRecognizer.unbox)
        disposables.append(gestureRecognizer)
    }
}
