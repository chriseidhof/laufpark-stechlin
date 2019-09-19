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
    private(set) var rates: [String: Double] = [:]
    private(set) var targetCurrency: String? = nil
    
    var currencies: [String] {
        return Array(rates.keys)
    }
    
    enum Message {
        case setInputText(String?)
        case dataReceived(Data?)
        case reload
        case selected(currency: String)
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
            self.rates = dataDict
            return nil
        case .reload:
            return .loadData(url: ratesURL, message: Message.dataReceived)
        case .selected(currency: let c):
            targetCurrency = c
            return nil
        }
    }
    
    var inputAmount: Double? {
        guard let text = inputText, let number = Double(text) else {
            return nil
        }
        return number
    }
    
    var outputAmount: Double? {
        guard let input = inputAmount, let c = targetCurrency, let rate = rates[c] else { return nil }
        return input * rate
    }
    
    var outputText: String {
        return outputAmount.map { "\(inputAmount!) EUR = \($0) \(targetCurrency!)" } ?? "..."
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
        rootViewController = view(state.i, { [weak self] msg in
            self?.send(msg)
        })
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

func conversionView(state: I<State>, send: @escaping (State.Message) -> ()) -> IBox<UIViewController> {
    let input = textField(text: state[\.inputText] ?? "", onChange: {
        send(.setInputText($0))
    })
    let inputSv = stackView(arrangedSubviews: [input.cast, label(text: I(constant: "EUR"), backgroundColor: I(constant: .white)).cast], axis: .horizontal)
    let outputLabel = label(text: state[\.outputText],
                                        backgroundColor: if_(state[\.inputAmount] == nil, then: .red, else: .white).map { $0 })
    let sv = stackView(arrangedSubviews: [
        inputSv.cast,
        outputLabel.cast,
    ])
    return viewController(rootView: sv,
                          constraints: [equalTop(), equalLeading(), equalTrailing()])
}

func view(state: I<State>, send: @escaping (State.Message) -> ()) -> IBox<UIViewController> {
    let currencies = state.map { $0.currencies }
    let table = tableViewController(items: currencies, didSelect: {
        send(.selected(currency: $0))
    }) { cell, currency in
        cell.textLabel?.text = currency
    }.map { $0 as UIViewController }
    let loading = activityIndicator(style: I(constant: .gray), animating: I(constant: true))
    let empty = viewController(rootView: loading, constraints: [equalCenterX(), equalCenterY()])
    let rootView = if_(currencies.map { $0.isEmpty}, then: empty, else: table)
    let vcs = flatten([rootView])
    let nc = navigationController(vcs)
    nc.disposables.append(state[\.targetCurrency].observe { selection in
        if selection != nil {
            // todo this isn't really how we should do it
            vcs.change(.insert(conversionView(state: state, send: send), at: 1))
        }
    })
    return nc.map { $0 }
}

import PlaygroundSupport
let driver = Driver<State>(initial: State(inputText: "100", rate: nil, rates: [:], targetCurrency: nil), view: view)
driver.send(.reload)
PlaygroundPage.current.liveView = driver.viewController
//: [Next](@next)
