//
//  StackViews.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

extension IBox where V == UIStackView {
    public convenience init<S>(arrangedSubviews: [IBox<S>], axis: UILayoutConstraintAxis = .vertical) where S: UIView {
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews.map { $0.unbox })
        stackView.axis = axis
        self.init(stackView)
        disposables.append(arrangedSubviews)
    }
    
    public convenience init<S>(arrangedSubviews: ArrayWithHistory<IBox<S>>, axis: UILayoutConstraintAxis = .vertical) where S: UIView {
        let stackView = UIStackView(arrangedSubviews: [])
        self.init(stackView)
        self.bindArrangedSubviews(to: arrangedSubviews)
    }
    
}

extension IBox where V: UIStackView {
    
    func addArrangedSubview<View: UIView>(_ i: IBox<View>) {
        disposables.append(i)
        unbox.addArrangedSubview(i.unbox)
    }
    
    func insertArrangedSubview<View: UIView>(_ subview: IBox<View>, at index: Int) {
        disposables.append(subview)
        unbox.insertArrangedSubview(subview.unbox, at: index)
    }
    
    func removeArrangedSubview<V: UIView>(_ subview: V) {
        guard let index = disposables.index(where: { ($0 as? IBox<V>)?.unbox === subview }) else {
            assertionFailure("Can't find subview.")
            return
        }
        disposables.remove(at: index)
        unbox.removeArrangedSubview(subview)
    }
    
    private func insert<V: UIView>(_ v: IBox<V>, at i: Int, duration: TimeInterval) {
        v.unbox.isHidden = true
        let offset = self.unbox.arrangedSubviews[0..<i].filter { $0.isHidden }.count
        self.insertArrangedSubview(v, at: i + offset)
        UIView.animate(withDuration: duration) {
            v.unbox.isHidden = false
        }
    }
        
    private func remove(at i: Int, duration: TimeInterval) {
        let v = self.unbox.arrangedSubviews.filter { !$0.isHidden }[i]
        UIView.animate(withDuration: duration, animations: {
            v.isHidden = true
        }, completion: { finished in
            if finished {
                self.removeArrangedSubview(v)
            }
        })

    }

    public func bindArrangedSubviews<Subview: UIView>(to value: ArrayWithHistory<IBox<Subview>>, animationDuration duration: TimeInterval = 0.2) {
        self.disposables.append(value.observe(current: { initialArrangedSubviews in
            assert(self.unbox.arrangedSubviews == [])
            for v in initialArrangedSubviews {
                self.addArrangedSubview(v)
            }
        }) {
            switch $0 {
            case let .insert(v, at: i):
                self.insert(v, at: i, duration: duration)
            case .remove(at: let i):
                self.remove(at: i, duration: duration)
            case let .replace(with: element, at: i):
                // todo guard if they're the same? or should we replace?
                self.insert(element, at: i, duration: duration)
                self.remove(at: i+1, duration: duration)
            case let .move(at: i, to: j):
                let offset = j > i ? -1 : 0
                let v = self.unbox.arrangedSubviews.filter { !$0.isHidden }[i]
                self.unbox.removeArrangedSubview(v)
                self.unbox.insertArrangedSubview(v, at: j + offset)
            }
        })
    }
}

public func stackView<V: UIView>(arrangedSubviews: [IBox<V>], axis: UILayoutConstraintAxis = .vertical, spacing: I<CGFloat> = I(constant: 10)) -> IBox<UIStackView> {
    let stackView = IBox<UIStackView>(arrangedSubviews: arrangedSubviews)
    stackView.unbox.axis = axis
    stackView.bind(spacing, to: \.spacing)
    return stackView
}


