//: [Previous](@previous)

import Foundation
import Incremental

let ratesURL = URL(string: "http://api.fixer.io/latest?base=EUR")!

enum Command<Message> {
    case loadData(url: URL, message: (Data?) -> Message)
}

struct State: Reducer {
    private(set) var inputText: String? = nil
    private(set) var rate: Double? = nil
    let targetCurrency = "USD"
    
    enum Message {
        case setInputText(String?)
        case dataReceived(Data?)
        case reload
    }
    
    
    mutating func send(_ message: Message) -> Command<Message>? {
        switch message {
        case .setInputText(let text):
            inputText = text
            return nil
        case .dataReceived(let data):
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: []),
                let dict = json as? [String:Any],
                let dataDict = dict["rates"] as? [String:Double] else { return nil }
            self.rate = dataDict[targetCurrency]
            return nil
        case .reload:
            return .loadData(url: ratesURL, message: Message.dataReceived)
        }
    }
    
    var inputAmount: Double? {
        guard let text = inputText, let number = Double(text) else {
            return nil
        }
        return number
    }
    
    var outputAmount: Double? {
        guard let input = inputAmount, let rate = rate else { return  nil }
        return input * rate
    }
    
    var outputText: String {
        return outputAmount.map { "\(inputAmount!) EUR = \($0) \(targetCurrency)" } ?? "..."
    }
}

extension State: Equatable {
    static func ==(lhs: State, rhs: State) -> Bool {
        return lhs.inputText == rhs.inputText && lhs.rate == rhs.rate
    }
}

protocol Reducer {
    associatedtype Message
    mutating func send(_ message: Message) -> Command<Message>?
}

class Driver<S> where S: Equatable, S: Reducer {
    let state: Input<S>
    private(set) var rootViewController: IBox<UIViewController>!
    
    var viewController: UIViewController {
        return rootViewController.unbox
    }
    
    init(initial: S, view: (I<S>, @escaping (S.Message) -> ()) -> IBox<UIViewController>) {
        state = Input(initial)
        rootViewController = view(state.i, send)
    }
    
    func send(_ message: S.Message) {
        self.state.change { x in
            if let command = x.send(message) {
                switch command {
                case let .loadData(url: url, message: transform):
                    URLSession.shared.dataTask(with: url) { (data, _, _) in
                        DispatchQueue.main.async { [weak self] in
                            self?.send(transform(data))
                        }
                    }.resume()

                }
            }
        }
    }
    
}

func stackView(arrangedSubviews: ArrayWithHistory<IBox<UIView>>) -> IBox<UIStackView> {
    let result = IBox<UIStackView>(arrangedSubviews: arrangedSubviews)
    return result
}

class TargetAction: NSObject {
    let callback: () -> ()
    init(_ callback: @escaping () -> ()) {
        self.callback = callback
    }
    @objc func action(_ sender: AnyObject) {
        callback()
    }
    deinit {
        print("Deiniting TargetAction")
    }
}

func textField(text: I<String>, onChange: @escaping (String?) -> ()) -> IBox<UITextField> {
    let textField = UITextField()
    let result = IBox(textField)
    result.bind(text, to: \.text)
    let ta = TargetAction {
        onChange(textField.text)
    }
    textField.addTarget(ta, action: #selector(TargetAction.action(_:)), for: .editingChanged)
    result.disposables.append(ta)
    textField.backgroundColor = .lightGray
    textField.frame = CGRect(x: 0, y: 0, width: 200, height: 30)
    return result
}

func label(text: I<String>, backgroundColor: I<UIColor> = I(constant: .white)) -> IBox<UILabel> {
    let label = IBox(UILabel())
    label.bind(text, to: \.text)
    label.bind(backgroundColor, to: \.backgroundColor)
    return label
}

func button(text: I<String>, onTap: @escaping () -> ()) -> IBox<UIButton> {
    let button = IBox(UIButton(type: .roundedRect))
    button.observe(value: text, onChange: { b, t in b.setTitle(t, for: .normal)})
    let ta = TargetAction(onTap)
    button.unbox.addTarget(ta, action: #selector(TargetAction.action(_:)), for: .touchUpInside)
    button.disposables.append(ta)
    return button
}

typealias Constraint = (_ parent: UIView, _ child: UIView) -> NSLayoutConstraint

func equalTop(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.topAnchor.constraint(equalTo: child.topAnchor)
}
func equalLeading(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.leadingAnchor.constraint(equalTo: child.leadingAnchor)
}
func equalTrailing(parent: UIView, child: UIView) -> NSLayoutConstraint {
    return parent.trailingAnchor.constraint(equalTo: child.trailingAnchor)
}


func viewController(rootView: IBox<UIView>, constraints: [Constraint] = []) -> IBox<UIViewController> {
    let vc = UIViewController()
    let box = IBox(vc)
    vc.view.addSubview(rootView.unbox)
    vc.view.backgroundColor = .white
    box.disposables.append(rootView)
    rootView.unbox.translatesAutoresizingMaskIntoConstraints = false
    for c in constraints {
        c(vc.view, rootView.unbox).isActive = true
    }
    return box
}

func view(state: I<State>, send: @escaping (State.Message) -> ()) -> IBox<UIViewController> {
    let input = textField(text: state.map { $0.inputText ?? "" }, onChange: {
        send(.setInputText($0))
    })
    let labelBgColor: I<UIColor> = state.map { $0.inputAmount == nil ? .red : .white }
    let outputLabel = label(text: state.map { $0.outputText }, backgroundColor: labelBgColor)
    let reload = button(text: I(constant: "Reload"), onTap: { send(.reload) })
    let stackView = IBox<UIStackView>(arrangedSubviews: [
        input.map { $0 },
        outputLabel.map { $0 },
        reload.map { $0 }
    ])
    stackView.unbox.axis = .vertical
    stackView.unbox.spacing = 10
    return viewController(rootView: stackView.map { $0 }, constraints: [equalTop, equalLeading, equalTrailing])
}

import PlaygroundSupport
let driver = Driver<State>(initial: State(inputText: "100", rate: nil), view: view)
PlaygroundPage.current.liveView = driver.viewController
//: [Next](@next)
