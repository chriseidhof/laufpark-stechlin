//: Playground - noun: a place where people can play

import Incremental

var str = "Hello, playground"


let arr = ArrayWithHistory<Int>([1,2,3])
let condition = Input<(Int) -> Bool>(alwaysPropagate: { _ in true })

func label(text: I<String>, backgroundColor: I<UIColor>) -> IBox<UILabel> {
    let label = UILabel()
    let result = IBox(label)
    result.bind(text, to: \.text)
    result.bind(backgroundColor, to: \.backgroundColor)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.heightAnchor.constraint(equalToConstant: 30).isActive = true
    return result
}


let filtered = arr.filter(condition.i)
let backgroundColor = Input(UIColor.white)
let labels = filtered.map { label(text: I(constant: "\($0)"), backgroundColor: backgroundColor.i) }

let s = UIStackView(arrangedSubviews: [])
let stackView = IBox(s)
s.axis = .vertical
s.distribution = .equalSpacing

stackView.bindArrangedSubviews(to: labels)

import PlaygroundSupport

s.frame = CGRect(x: 0, y: 0, width: 200, height: 300)
PlaygroundPage.current.liveView = s

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
    arr.change(.insert(4, at: 3))
})

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2), execute: {
    condition.write { $0 % 2 == 0 }
})

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3), execute: {
    backgroundColor.write(.red)
})

