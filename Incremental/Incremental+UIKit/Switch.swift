//
//  Switch.swift
//  Incremental
//
//  Created by Chris Eidhof on 02.12.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

public func uiSwitch(value: I<Bool>, valueChange: @escaping (_ isOn: Bool) -> ()) -> IBox<UISwitch> {
    let view = UISwitch()
    let result = IBox(view)
    result.handle(.valueChanged) { [unowned view] in
        valueChange(view.isOn)
    }
    result.bind(value, to: \.isOn)
    return result
}
