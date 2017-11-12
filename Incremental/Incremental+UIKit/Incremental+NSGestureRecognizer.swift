//  Incremental
//
//  Created by Chris Eidhof on 22.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Cocoa

public func clickGestureRecognizer(_ tapped: @escaping (NSClickGestureRecognizer) -> ()) -> IBox<NSClickGestureRecognizer> {
    let recognizer = NSClickGestureRecognizer()
    let targetAction = TargetAction { tapped(recognizer) }
    recognizer.target = targetAction
    recognizer.action = #selector(TargetAction.action(_:))
    let result = IBox(recognizer)
    result.disposables.append(targetAction)
    return result
}

extension IBox where V: NSView {
    public func addGestureRecognizer<G: NSGestureRecognizer>(_ gestureRecognizer: IBox<G>) {
        self.unbox.addGestureRecognizer(gestureRecognizer.unbox)
        disposables.append(gestureRecognizer)
    }
}

