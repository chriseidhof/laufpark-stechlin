//
//  AppDelegate.swift
//  Todos
//
//  Created by Chris Eidhof on 11-10-17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import Incremental
import IncrementalElm

struct Todo: Codable, Equatable {
    static func ==(lhs: Todo, rhs: Todo) -> Bool {
        return lhs.done == rhs.done && lhs.title == rhs.title
    }
    
    let title: String
    var done: Bool
}

func <(lhs: Todo, rhs: Todo) -> Bool {
    if lhs.done == rhs.done {
        return lhs.title < rhs.title
    } else {
        return lhs.done && !rhs.done
    }
}

struct State: RootComponent {
    let todos: ArrayWithHistory<Todo> = ArrayWithHistory<Todo>([])
    
    enum Message {
        case newTodo
        case add(String?)
        case delete(Todo)
        case select(Todo)
    }
    
    mutating func send(_ message: Message) -> [Command<Message>] {
        switch message {
        case .delete(let todo):
            todos.remove(where: { $0 == todo})
        case .select(at: let todo):
            if let index = todos.index(of: todo) {
                todos.mutate(at: index) { $0.done = !$0.done }
            }
        case .newTodo:
            return [.modalTextAlert(title: "Item title", accept: "OK", cancel: "Cancel", placeholder: "", convert: Message.add)]
        case .add(let text):
            if let t = text {
                todos.append(Todo(title: t, done: false))
            }
        }
        return []
    }
    
    static func ==(lhs: State, rhs: State) -> Bool {
        return lhs.todos == rhs.todos
    }
    
}

func emptyVC(text: String) -> IBox<UIViewController> {
    return viewController(rootView: label(text: I(constant: text)), constraints: [
        equalCenterX(), equalCenterY()])

}

func render(state: I<State>, send: @escaping (State.Message) -> ()) -> IBox<UIViewController> {
    let items = state[\.todos].map { $0.sort(by: I(constant: <)) }
    let tableVC: IBox<UIViewController> = tableViewController(items: items, didSelect: { send(.select($0)) }, didDelete: { send(.delete($0)) }, configure: { cell, todo in
        cell.textLabel?.text = todo.title
        cell.accessoryType = todo.done ? .checkmark : .none
    }).map { $0 }
    
    let add = { barButtonItem(systemItem: .add, onTap: { send(.newTodo) }) }
    tableVC.setRightBarButtonItems([add()])
    
    let e = emptyVC(text: "No todos yet.")
    e.setRightBarButtonItems([add()])
    
    let vc = if_(state[\.todos].flatMap { $0.isEmpty }, then: e, else: tableVC)
    
    let navigationVC = navigationController(flatten([vc]))
    return navigationVC.map { $0 }
}


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let driver = Driver(State(), render: render)


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = driver.viewController
        window?.makeKeyAndVisible()
        return true
    }
}

