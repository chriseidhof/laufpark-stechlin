//
//  IncrementalStdLib.swift
//  Incremental
//
//  Created by Chris Eidhof on 19.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

public func if_<A: Equatable>(_ condition: I<Bool>, then l: I<A>, else r: I<A>) -> I<A> {
    return condition.flatMap { $0 ? l : r }
}

public func if_<A: Equatable>(_ condition: I<Bool>, then l: A, else r: A) -> I<A> {
    return condition.map { $0 ? l : r }
}

public func &&(l: I<Bool>, r: I<Bool>) -> I<Bool> {
    return l.zip2(r, { $0 && $1 })
}

public func ||(l: I<Bool>, r: I<Bool>) -> I<Bool> {
    return l.zip2(r, { $0 || $1 })
}

public prefix func !(l: I<Bool>) -> I<Bool> {
    return l.map { !$0 }
}

public func ==<A>(l: I<A>, r: I<A>) -> I<Bool> where A: Equatable {
    return l.zip2(r, ==)
}

public func ==<A>(l: I<A>, r: A) -> I<Bool> where A: Equatable {
    return l.map { $0 == r }
}

enum IList<A>: Equatable where A: Equatable {
    case empty
    case cons(A, I<IList<A>>)
    
    mutating func append(_ value: A) {
        switch self {
        case .empty: self = .cons(value, I(value: .empty))
        case .cons(_, let tail): tail.value.append(value)
        }
    }
    
    func reduceH<B>(destination: I<B>, initial: B, combine: @escaping (A,B) -> B) -> Node {
        switch self {
        case .empty:
            destination.write(initial)
            return destination
        case let .cons(value, tail):
            let intermediate = combine(value, initial)
            return tail.read(target: destination) { newTail in
                newTail.reduceH(destination: destination, initial: intermediate, combine: combine)
            }
        }
    }
}

extension IList {
    static func ==(l: IList<A>, r: IList<A>) -> Bool {
        switch (l, r) {
        case (.empty, .empty): return true
        default: return false
        }
    }
}

