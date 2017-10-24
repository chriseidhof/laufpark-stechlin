//
//  Incremental+UIKit.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

extension UIView {
    public func addSubview(_ subview: UIView, constraints: [Constraint]) {
        addSubview(subview)
        if !constraints.isEmpty {
            subview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate(constraints.map { $0(self, subview) })
        }

    }
}

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

    public func addSubview<S>(_ subview: IBox<S>, path: KeyPath<V,UIView>? = nil, constraints: [Constraint] = []) where S: UIView {
        disposables.append(subview)
        let target: UIView = path.map { kp in unbox[keyPath: kp] } ?? unbox
        target.addSubview(subview.unbox, constraints: constraints)
        
    }
    
    private func insert<View: UIView>(_ subview: IBox<View>, at index: Int) {
        self.disposables.append(subview)
        self.unbox.insertSubview(subview.unbox, at: index)
    }
    
    private func remove<View: UIView>(at index: Int, ofType: View.Type) {
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
    
    public func bindSubviews<View: UIView>(_ iArray: I<ArrayWithHistory<IBox<View>>>) {
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
    
    public var cast: IBox<UIView> {
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

