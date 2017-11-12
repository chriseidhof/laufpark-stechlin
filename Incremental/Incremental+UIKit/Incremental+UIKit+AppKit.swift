//
//  Incremental+UIKit+AppKit.swift
//  Incremental
//
//  Created by Chris Eidhof on 12.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

#if os(OSX)
    import Cocoa
    public typealias IncColor = NSColor
    public typealias IncView = NSView
#else
    import UIKit
    public typealias IncView = UIView
    public typealias IncColor = UIColor
#endif


#if os(OSX)
    extension NSView {
        func insertSubview(_ s: NSView, at index: Int) {
            self.subviews.insert(s, at: index)
        }
    }
#endif


extension IncView {
    public func addSubview<V: IncView>(_ subview: V, constraints: [NSLayoutConstraint]) {
        addSubview(subview)
        if !constraints.isEmpty {
            subview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(constraints)
        }
        
    }
}


extension IBox where V: IncView {
    public func addSubview<S>(_ subview: IBox<S>, path: KeyPath<V,IncView>? = nil, constraints: [Constraint] = []) where S: IncView {
        disposables.append(subview)
        let target: IncView = path.map { kp in unbox[keyPath: kp] } ?? unbox
        let evaluatedConstraints = constraints.map { $0(self.unbox, subview.unbox) }
        target.addSubview(subview.unbox, constraints: evaluatedConstraints.map { $0.unbox })
        disposables.append(evaluatedConstraints)
        
    }
    
    private func insert<View: IncView>(_ subview: IBox<View>, at index: Int) {
        self.disposables.append(subview)
        self.unbox.insertSubview(subview.unbox, at: index)        
    }
    
    private func remove<View: IncView>(at index: Int, ofType: View.Type) {
        let oldView = self.unbox.subviews[index] as! View
        guard let i = self.disposables.index(where: {
            if let oldDisposable = $0 as? IBox<View>, oldDisposable.unbox == oldView {
                return true
            }
            return false
        }) else {
            fatalError()
        }
        self.disposables.remove(at: i)
        oldView.removeFromSuperview()
    }
    
    public func bindSubviews<View: IncView>(_ iArray: I<ArrayWithHistory<IBox<View>>>) {
        // todo replace with custom array observing
        disposables.append(iArray.observe { value in // todo owernship of self?
            assert(self.unbox.subviews.isEmpty)
            for view in value.initial { self.unbox.addSubview(view.unbox) }
            value.changes.read { changeList in
                return changeList.reduce(eq: { _,_ in false }, initial: (), combine: { (change, _) in
                    
                    switch change {
                    case let .insert(subview, index):
                        self.insert(subview, at: index)
                    case .remove(let index):
                        self.remove(at: index, ofType: View.self)
                    case let .replace(with: subview, at: i):
                        self.insert(subview, at: i)
                        self.remove(at: i+1, ofType: View.self)
                    case let .move(at: i, to: j):
                        let view = self.unbox.subviews[i]
                        view.removeFromSuperview()
                        let offset = j > i ? -1 : 0
                        self.unbox.insertSubview(view, at: j + offset)
                        
                    }
                    return ()
                })
            }
        })
    }
    
    public var cast: IBox<IncView> {
        return map { $0 }
    }
}

public class TargetAction: NSObject {
    let callback: () -> ()
    public init(_ callback: @escaping () -> ()) {
        self.callback = callback
    }
    @objc public func action(_ sender: AnyObject) {
        callback()
    }
}
