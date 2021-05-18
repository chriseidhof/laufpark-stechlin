//
//  ActivityIndicator.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

extension UIActivityIndicatorView {
    var animating: Bool {
        get { return isAnimating }
        set {
            if newValue { self.startAnimating() }
            else { self.stopAnimating() }
        }
    }
}

public func activityIndicator(style: I<UIActivityIndicatorView.Style> = I(constant: .white), animating: I<Bool>) -> IBox<UIView> {
    let loadingIndicator = IBox(UIActivityIndicatorView())
    loadingIndicator.unbox.hidesWhenStopped = true
    loadingIndicator.bind(animating, to: \.animating)
    loadingIndicator.bind(style, to: \.style)
    return loadingIndicator.cast
}
