//
//  Button.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public func button(type: UIButtonType = .custom, title: I<String>, backgroundColor: I<UIColor> = I(constant: .white), titleColor: I<UIColor?> = I(constant: nil), onTap: @escaping () -> ()) -> IBox<UIButton> {
    let result = IBox<UIButton>(UIButton(type: type))
    result.bind(backgroundColor, to: \.backgroundColor)
    result.observe(value: title, onChange: { $0.setTitle($1, for: .normal) })
    result.observe(value: titleColor, onChange: { $0.setTitleColor($1, for: .normal)})
    result.handle(.touchUpInside, onTap)
    return result
}

// todo dry
public func button(type: UIButtonType = .custom, titleImage: I<UIImage>, backgroundColor: I<UIColor> = I(constant: .white), onTap: @escaping () -> ()) -> IBox<UIButton> {
    let result = IBox<UIButton>(UIButton(type: type))
    result.bind(backgroundColor, to: \.backgroundColor)
    result.observe(value: titleImage, onChange: { $0.setImage($1, for: .normal) })
    result.handle(.touchUpInside, onTap)
    return result
}

extension IBox where V: UIControl {
    public func handle(_ events: UIControlEvents, _ handler: @escaping () -> ()) {
        let ta = TargetAction(handler)
        unbox.addTarget(ta, action: #selector(TargetAction.action(_:)), for: events)
        disposables.append(ta)
    }
}
