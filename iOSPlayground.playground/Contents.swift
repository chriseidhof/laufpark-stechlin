//: Playground - noun: a place where people can play

import Incremental

var str = "Hello, playground"

let arr = ArrayWithHistory<Int>([1,2,3])
let condition = Input<(Int) -> Bool>(alwaysPropagate: { _ in true })

func label(text: I<String>) -> IBox<UILabel> {
    let label = UILabel()
    let result = IBox(label)
    result.bind(text, to: \.text)
    label.translatesAutoresizingMaskIntoConstraints = false
    label.heightAnchor.constraint(equalToConstant: 30).isActive = true
    label.backgroundColor = .white
    return result
}

let filtered = arr.filter(condition.i)
let labels = filtered.map { $0.map { label(text: I(constant: "\($0)")) } }

let s = UIStackView(arrangedSubviews: [])
let stackView = IBox(s)
s.axis = .vertical
s.distribution = .equalSpacing
s.frame = CGRect(x: 0, y: 0, width: 200, height: 300    )
stackView.bindArrangedSubviews(to: labels)

import PlaygroundSupport

PlaygroundPage.current.liveView = s

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
    arr.change(.insert(4, at: 3))
})

DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(3), execute: {
    condition.write { $0 > 2 }
})

