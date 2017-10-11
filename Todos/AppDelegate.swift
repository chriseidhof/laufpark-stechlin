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

struct State: RootComponent {
    var todos: ArrayWithHistory<Todo> = ArrayWithHistory<Todo>([])
    
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


func render(state: I<State>, send: @escaping (State.Message) -> ()) -> IBox<UIViewController> {
    let tableVC: IBox<UIViewController> = tableViewController(items: state[\.todos], didSelect: { item in
        send(.select(item))
    }, didDelete: { item in
        send(.delete(item))
    }, configure: { cell, todo in
        cell.textLabel?.text = todo.title
        cell.accessoryType = todo.done ? .checkmark : .none
    }).map { $0 }
    
    let add = barButtonItem(systemItem: .add, onTap: { send(.newTodo) })
    tableVC.setRightBarButtonItems([add])
    
    let navigationVC = navigationController(ArrayWithHistory([tableVC]))
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

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

