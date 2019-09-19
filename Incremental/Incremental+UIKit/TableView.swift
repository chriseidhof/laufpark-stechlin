//
//  TableViews.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

final class TableVC<A>: UITableViewController {
    var items: [A] = []
    let configure: (UITableViewCell,A) -> ()
    let didSelect: ((A) -> ())?
    let didDelete: ((A) -> ())?
    
    init(_ items: [A], didSelect: ((A) -> ())? = nil, didDelete: ((A) -> ())? = nil, configure: @escaping (UITableViewCell,A) -> ()) {
        self.items = items
        self.configure = configure
        self.didSelect = didSelect
        self.didDelete = didDelete
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Identifier")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelect?(items[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        didDelete?(items[indexPath.row])
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Identifier")!
        configure(cell, items[indexPath.row])
        return cell
    }
}

extension TableVC where A: Equatable {
    func apply(_ change: ArrayChange<A>) {
        items.apply(change)
        switch change {
        case let .insert(_, at: index):
            let indexPath = IndexPath(row: index, section: 0)
            tableView.insertRows(at: [indexPath], with: .automatic)
        case let .remove(at: index):
            let indexPath = IndexPath(row: index, section: 0)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        case let .replace(with: _, at: index):
            let indexPath = IndexPath(row: index, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        case let .move(at: i, to: j):
            tableView.moveRow(at: IndexPath(row: i, section: 0), to: IndexPath(row: j, section: 0))
        }
    }
}

public func tableViewController<A>(items value: ArrayWithHistory<A>, didSelect: ((A) -> ())? = nil, configure: @escaping (UITableViewCell, A) -> ()) -> IBox<UITableViewController> {
    let tableVC = TableVC([], didSelect: didSelect, configure: configure)
    let box = IBox<UITableViewController>(tableVC)
    box.disposables.append(value.observe(current: {
        tableVC.items = $0
    }, handleChange: { change in
        tableVC.apply(change)
    }))
    return box
}

public func tableViewController<A>(items: I<ArrayWithHistory<A>>, didSelect: ((A) -> ())? = nil, didDelete: ((A) -> ())? = nil, configure: @escaping (UITableViewCell, A) -> ()) -> IBox<UITableViewController> {
    let tableVC = TableVC([], didSelect: didSelect, didDelete: didDelete, configure: configure)
    let box = IBox<UITableViewController>(tableVC)
    var previousObserver: Any? // this warning is expected, we need to retain the previousObserver
    box.disposables.append(items.observe { value in
        previousObserver = nil
        previousObserver = value.observe(current: {
            tableVC.items = $0
            tableVC.tableView.reloadData()
        }, handleChange: { change in
            tableVC.apply(change)
        })
    })
    return box
}

public func tableViewController<A>(items value: I<[A]>, didSelect: ((A) -> ())? = nil,  configure: @escaping (UITableViewCell, A) -> ()) -> IBox<UITableViewController> {
    let tableVC = TableVC([], didSelect: didSelect, configure: configure)
    let box = IBox<UITableViewController>(tableVC)
    box.disposables.append(value.observe {
        tableVC.items = $0
        tableVC.tableView.reloadData()
    })
    return box
}
