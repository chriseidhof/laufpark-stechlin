//
//  Incremental+UIKit.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation


extension IBox where V: UIView {
    public func addSubview<S>(_ subview: IBox<S>) where S: UIView {
        disposables.append(subview)
        unbox.addSubview(subview.unbox)
    }
    
    public func bindSubviews<View: UIView>(_ iArray: I<ArrayWithHistory<IBox<View>>>) {
        
        disposables.append(iArray.observe { value in // todo owernship of self?
            assert(self.unbox.subviews.isEmpty)
            for view in value.initial { self.unbox.addSubview(view.unbox) }
            value.changes.read { changeList in
                return changeList.reduce(eq: { _,_ in false }, initial: (), combine: { (change, _) in
                    switch change {
                    case let .insert(subview, index):
                        self.disposables.append(subview)
                        self.unbox.insertSubview(subview.unbox, at: index)
                    case .remove(let index):
                        // todo remove disposable!
                        self.unbox.subviews[index].removeFromSuperview()
                    }
                    return ()
                })
            }
        })
    }
}

extension IBox where V: UIStackView {
    public convenience init<S>(arrangedSubviews: [IBox<S>]) where S: UIView {
        let stackView = UIStackView(arrangedSubviews: arrangedSubviews.map { $0.unbox })
        self.init(stackView)
        disposables.append(arrangedSubviews)
    }
}

extension IBox where V: UIStackView {
    public func bindArrangedSubviews<Subview: UIView>(to value: ArrayWithHistory<IBox<Subview>>, animationDuration duration: TimeInterval = 0.2) {
        self.disposables.append(value.observe(current: { initialArrangedSubviews in
            assert(self.unbox.arrangedSubviews == [])
            for v in initialArrangedSubviews {
                self.unbox.addArrangedSubview(v.unbox)
            }
        }) {
            switch $0 {
            case let .insert(v, at: i):
                v.unbox.isHidden = true
                self.unbox.insertArrangedSubview(v.unbox, at: i)
                UIView.animate(withDuration: duration) {
                    v.unbox.isHidden = false
                }
            case .remove(at: let i):
                let v = self.unbox.arrangedSubviews.filter { !$0.isHidden }[i]
                UIView.animate(withDuration: duration, animations: {
                    v.isHidden = true
                }, completion: { _ in
                    self.unbox.removeArrangedSubview(v)
                })
            }
        })
    }
}

final class TableVC<A>: UITableViewController {
    var items: [A] = []
    let configure: (UITableViewCell,A) -> ()
    
    init(_ items: [A], configure: @escaping (UITableViewCell,A) -> ()) {
        self.items = items
        self.configure = configure
        super.init(style: .plain)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    override func viewDidLoad() {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Identifier")
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
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
        }
    }
}

public func tableViewController<A>(items value: ArrayWithHistory<A>, configure: @escaping (UITableViewCell, A) -> ()) -> IBox<UITableViewController> {
    let tableVC = TableVC([], configure: configure)
    let box = IBox<UITableViewController>(tableVC)
    box.disposables.append(value.observe(current: {
        tableVC.items = $0
    }, handleChange: { change in
        tableVC.apply(change)
    }))
    return box
}
