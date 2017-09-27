//: [Previous](@previous)

import Foundation
import Incremental

let x = Input(5)
let y = Input(6)

func add(_ lhs: I<Int>, _ rhs: I<Int>) -> I<Int> {
    return lhs.zip2(rhs, { $0 + $1 })
}

let arr = ArrayWithHistory([1,2,3])

let condition: Input<(Int) -> Bool> = Input(alwaysPropagate: { $0 > 0 })
let disposable = arr.filter(condition.i).observe(current: {
    print("initial: \($0)")
}, handleChange: { change in print("change: \(change)") })

arr.change(.insert(4, at: 3))
condition.write { $0 % 2 == 0 }
