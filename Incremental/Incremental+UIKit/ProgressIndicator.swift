//
//  ProgressIndicator.swift
//  Incremental
//
//  Created by Chris Eidhof on 29.11.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public func progressView(progress: I<Float>) -> IBox<UIProgressView> {
    let result = UIProgressView(progressViewStyle: .default)
    let box = IBox(result)
    box.bind(progress, to: \.progress)
    return box
}
