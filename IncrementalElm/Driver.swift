import UIKit
import Incremental

public protocol RootComponent: Equatable /*, Codable*/ {
	associatedtype Message
	mutating func send(_: Message) -> [Command<Message>]
}

final public class Driver<Model> where Model: RootComponent {
	private var model: Input<Model>
	private var rootView: IBox<UIViewController>!
    public var viewController: UIViewController { return rootView.unbox }
	
    public init(_ initial: Model, render: (I<Model>, _ send: @escaping (Model.Message) -> ()) -> IBox<UIViewController>, commands: [Command<Model.Message>] = []) {
		model = Input(initial)
        rootView = render(model.i) { [unowned self] in self.send(action: $0) }
		for command in commands {
			interpret(command: command)
		}
	}
		
	public func send(action: Model.Message) { // todo this should probably be in a serial queue
        let commands = model.change { $0.send(action) }
		for command in commands {
			interpret(command: command)
		}
	}
	
	func asyncSend(action: Model.Message) {
		DispatchQueue.main.async {
			self.send(action: action)
		}
	}
	
	func interpret(command: Command<Model.Message>) {
		command.interpret(viewController: viewController, callback: self.asyncSend)
	}
}
