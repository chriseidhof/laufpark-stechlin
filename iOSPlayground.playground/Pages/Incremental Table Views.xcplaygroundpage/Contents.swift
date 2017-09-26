//: Playground - noun: a place where people can play

import Incremental

var str = "Hello, playground"

let arr = ArrayWithHistory(["one", "two", "three", "four"])
let condition = Input<(String) -> Bool>(alwaysPropagate: { _ in true })
let filtered = arr.filter(condition.i)

let s = tableViewController(items: filtered, configure: { cell, text in
    cell.textLabel?.text = text
})

import PlaygroundSupport

s.unbox.view.frame = CGRect(x: 0, y: 0, width: 200, height: 300)
PlaygroundPage.current.liveView = s.unbox

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
    arr.change(.insert("five", at: 4))
})

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3), execute: {
    condition.write { $0.count > 3 }
})
