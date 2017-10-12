//
//  BlurView.swift
//  Laufpark
//
//  Created by Florian Kugler on 12-10-2017.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

final class BlurView: UIView {
    init(contentView: UIView) {
        super.init(frame: .zero)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        blur.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blur)
        blur.addConstraintsToSizeToParent()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(contentView)
        contentView.addConstraintsToSizeToParent()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
