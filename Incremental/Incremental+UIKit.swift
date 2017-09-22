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
}

extension IBox where V == UIStackView {
    public convenience init<S>(arrangedSubviews: [IBox<S>]) where S: UIView {
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews.map { $0.unbox })
        self.init(stackView)
        disposables.append(arrangedSubviews)
    }
}
