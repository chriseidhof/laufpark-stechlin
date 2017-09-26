//
//  Incremental+UIKit.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation


extension IBox where V: UIView {
    public func addSubview<S>(_ subview: IBox<S>) where S: UIView {
        disposables.append(subview)
        unbox.addSubview(subview.unbox)
    }
    
    public func bindSubviews(_ iArray: I<ArrayWithHistory<IBox<UIView>>>) {
        
        disposables.append(iArray.observe { value in // todo owernship of self?
            assert(self.unbox.subviews.isEmpty)
            for view in value.initial { self.unbox.addSubview(view.unbox) }
            value.changes.read { changeList in
                return changeList.reduce(eq: { _,_ in false }, initial: (), combine: { (change, _) in
                    switch change {
                    case let .insert(subview, index):
                        self.disposables.append(subview)
                        self.unbox.insertSubview(subview.unbox, at: index)
                    case .remove(let index):
                        // todo remove disposable!
                        self.unbox.subviews[index].removeFromSuperview()
                    }
                    return ()
                })
            }
        })
    }
}

extension IBox where V == UIStackView {
    public convenience init<S>(arrangedSubviews: [IBox<S>]) where S: UIView {
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews.map { $0.unbox })
        self.init(stackView)
        disposables.append(arrangedSubviews)
    }
}

extension IBox where V: UIStackView {
    public func bindArrangedSubviews<Subview: UIView>(to: I<ArrayWithHistory<IBox<Subview>>>, animationDuration duration: TimeInterval = 0.2) {
        // todo: this assumes that to never changes. this is true, but still: fix it.
        to.observe { value in // todo ownership
            self.disposables.append(value.observe(current: { initialArrangedSubviews in
                assert(self.unbox.arrangedSubviews == [])
                for v in initialArrangedSubviews {
                    self.unbox.addArrangedSubview(v.unbox)
                }
            }) {
                switch $0 {
                case let .insert(v, at: i):
                    v.unbox.isHidden = true
                    self.unbox.insertArrangedSubview(v.unbox, at: i)
                    UIView.animate(withDuration: duration) {
                        v.unbox.isHidden = false
                    }
                case .remove(at: let i):
                    let v = self.unbox.arrangedSubviews.filter { !$0.isHidden }[i]
                    UIView.animate(withDuration: duration, animations: {
                        v.isHidden = true
                    }, completion: { _ in
                        self.unbox.removeArrangedSubview(v)
                    })
                }
            })
        }
    }
}
