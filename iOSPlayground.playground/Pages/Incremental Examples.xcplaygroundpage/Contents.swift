//: [Previous](@previous)

import Foundation
import Incremental

func segment(text: I<String>, image: I<UIImage>, selected: I<Bool>) -> UIView {
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 63, height: 73))
    let image = UIImageView(image: #imageLiteral(resourceName: "map.png"))
    view.backgroundColor = .lightGray
    let label = UILabel()
    label.bind(keyPath: \.text, text.map { $0 })
    label.textAlignment = .center
    label.font = UIFont.preferredFont(forTextStyle: .caption1)
    let selection = UIView()
    selection.backgroundColor = .black
    selection.heightAnchor.constraint(equalToConstant: 2)
    let stack = UIStackView(arrangedSubviews: [
        image,
        selection,
        label
    ])
    view.addSubview(stack)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.leftAnchor.constraint(equalTo: view.leftAnchor)
    stack.rightAnchor.constraint(equalTo: view.rightAnchor)
    stack.topAnchor.constraint(equalTo: view.topAnchor)
    stack.axis = .vertical
    view.isUserInteractionEnabled = true
    return view
}

import PlaygroundSupport
let result = segment(text: I(constant: "KARTE"), image: I(constant: #imageLiteral(resourceName: "map.png")), selected: I(constant: true))
PlaygroundPage.current.liveView = result
result.frame
result.subviews.first?.subviews.map { $0.frame.height }
