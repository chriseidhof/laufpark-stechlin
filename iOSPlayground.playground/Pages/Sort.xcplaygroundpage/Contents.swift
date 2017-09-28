//: [Previous](@previous)

import Foundation
import Incremental

let arr = ArrayWithHistory([1,2,3])

let sortOrder: Input<(Int, Int) -> Bool> = Input(alwaysPropagate: >)
let sorted = arr.sort(by: sortOrder.i)
let d = sorted.observe(current: {
    print("initial: \($0)")
}, handleChange: { change in print("change: \(change)") })

arr.change(.insert(10, at: 3))
arr.change(.insert(11, at: 0))

sortOrder.write(<)

