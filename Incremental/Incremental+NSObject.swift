//
//  Incremental+NSObject.swift
//  Incremental
//
//  Created by Chris Eidhof on 18.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation


// Could this be in a conditional block? Only works for Foundation w/ ObjC runtime
extension NSObjectProtocol where Self: NSObject {
    public subscript<Value>(_ keyPath: KeyPath<Self, Value>) -> I<Value> where Value: Equatable {
        let i: I<Value> = I(value: self[keyPath: keyPath])
        let observation = observe(keyPath) { (obj, change) in
            i.write(obj[keyPath: keyPath])
        }
        i.strongReferences.add(observation)
        return i
    }
}

public final class IBox<V: NSObject> {
    public let view: V
    var disposables: [Any] = []
    public init(_ view: V = V()) {
        self.view = view
    }
    
    public func bind<A>(_ value: I<A>, to: ReferenceWritableKeyPath<V,A>) {
        disposables.append(view.bind(keyPath: to, value))
    }
    
    public func bind<A>(_ value: I<A>, to: ReferenceWritableKeyPath<V,A?>) where A: Equatable {
        disposables.append(view.bind(keyPath: to, value.map { $0 }))
    }
    
    public func observe<A>(value: I<A>, onChange: @escaping (V,A) -> ()) {
        disposables.append(value.observe { newValue in
            onChange(self.view,newValue) // ownership?
        })
    }
    
    public subscript<A>(keyPath: KeyPath<V,A>) -> I<A> where A: Equatable {
        return view[keyPath]
    }
}

extension NSObjectProtocol {
    /// One-way binding
    public func bind<Value>(keyPath: ReferenceWritableKeyPath<Self, Value>, _ i: I<Value>) -> Disposable {
        return i.observe {
            self[keyPath: keyPath] = $0
        }
    }
}

