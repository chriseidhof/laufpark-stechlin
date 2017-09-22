//
//  IncrementalList.swift
//  Incremental
//
//  Created by Chris Eidhof on 20.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

// todo shouldn't be public probably
public func appendOnly<A>(_ value: A, to: I<IList<A>>) {
    concatOnly(.cons(value, I(value: .empty)), to: to)
}

// concat to an immutable list
func concatOnly<A>(_ value: IList<A>, to: I<IList<A>>) {
    if case .empty = value { return }
    switch to.value! {
    case .empty:
        to.write(constant: value)
    case .cons(_, let tail):
        concatOnly(value, to: tail)
    }
}

func tail<A>(_ source: I<IList<A>>) -> I<IList<A>> {
    switch source.value! {
    case .cons(_, let t): return tail(t)
    case .empty: return self
    }
}

public indirect enum IList<A>: Equatable, CustomDebugStringConvertible where A: Equatable {

    case empty
    case cons(A, I<IList<A>>)

    public mutating func append(_ value: A) {
        switch self {
        case .empty: self = .cons(value, I(value: .empty))
        case .cons(_, let tail): tail.value.append(value)
        }
    }

    public mutating func concat(_ tail: IList<A>) {
        switch self {
        case .empty: self = tail
        case .cons(_, let t): t.value.concat(tail)
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

    public func reduce<B>(initial: B, combine: @escaping (A,B) -> B) -> I<B> where B: Equatable {
        return reduce(eq: ==, initial: initial, combine: combine)
    }

    public func reduce<B>(eq: @escaping (B,B) -> Bool, initial: B, combine: @escaping (A,B) -> B) -> I<B> {
        let result = I<B>(eq: eq)
        let node = reduceH(destination: result, initial: initial, combine: combine)
        result.strongReferences.add(node)
        return result
    }

    public var debugDescription: String {
        var result: [A] = []
        var x = self
        while case let .cons(value, remainder) = x {
            result.append(value)
            x = remainder.value
        }
        return "IList(\(result))"
    }
}

extension IList {
    public static func ==(l: IList<A>, r: IList<A>) -> Bool {
        switch (l, r) {
        case (.empty, .empty): return true
        default: return false
        }
    }
}

public enum ArrayChange<Element>: Equatable where Element: Equatable {
    case insert(Element, at: Int)
    case remove(at: Int)

    public static func ==(lhs: ArrayChange<Element>, rhs: ArrayChange<Element>) -> Bool {
        switch (lhs, rhs) {
        case (.insert(let e1, let a1), .insert(let e2, let a2)):
            return e1 == e2 && a1 == a2
        case (.remove(let i1), .remove(let i2)):
            return i1 == i2
        default:
            return false
        }
    }
}

extension Array where Element: Equatable {
    func applying(_ change: ArrayChange<Element>) -> [Element] {
        var copy = self
        copy.apply(change)
        return copy
    }
    public mutating func apply(_ change: ArrayChange<Element>) {
        switch change {
        case let .insert(e, at: i):
            self.insert(e, at: i)
        case .remove(at: let i):
            self.remove(at: i)
        }
    }
}

extension Array {
    func filteredIndex(for index: Int, _ isIncluded: (Element) -> Bool) -> Int {
        var skipped = 0
        for i in 0..<index {
            if !isIncluded(self[i]) {
                skipped += 1
            }
        }
        return index - skipped
    }
}

extension Array where Element: Equatable {
    func filterChanges(oldCondition: (Element) -> Bool, newCondition: (Element) -> Bool) -> IList<ArrayChange<Element>> {
        // TODO: this is O(n^2) because of filteredIndex. Should be possible to make it O(n)
        var result: IList<ArrayChange<Element>> = .empty
        for (element, index) in zip(self, self.indices) {
            let old = oldCondition(element)
            let new = newCondition(element)
            let newIndex = filteredIndex(for: index, oldCondition)
            if old && !new {
                result.append(ArrayChange<Element>.remove(at: newIndex))
            } else if !old && new {
                result.append(.insert(element, at: newIndex))
            }
        }
        return result
    }
}

public struct ArrayWithHistory<A: Equatable>: Equatable {
    let initial: [A]
    public let changes: I<IList<ArrayChange<A>>> // todo: this should be write-only
    public init(_ initial: [A]) {
        self.initial = initial
        self.changes = I(value: .empty)
    }

    public mutating func change(_ change: ArrayChange<A>) {
        appendOnly(change, to: changes)
    }

    public static func ==(lhs: ArrayWithHistory<A>, rhs: ArrayWithHistory<A>) -> Bool {
        return lhs.initial == rhs.initial && lhs.changes.value == rhs.changes.value
    }
}

func filterH<A>(target: I<()>, changesOut: I<IList<ArrayChange<A>>>, changesIn: IList<ArrayChange<A>>, condition: @escaping (A) -> Bool, latest: [A]) -> Node {
    switch changesIn {
    case .empty:
        return target.write(())
        // return target // tail(changesOut) // todo no idea what to return here?!
    case .cons(let change, let remainder):
        switch change {
        case let .insert(element, at: index) where condition(element):
            print("got a valid insert: \(change)")
            let newIndex = latest.filteredIndex(for: index, condition)
            appendOnly(.insert(element, at: newIndex), to: changesOut)
        case let .remove(at: index) where condition(latest[index]):
            print("got a valid remove: \(change)")
            let newIndex = latest.filteredIndex(for: index, condition)
            appendOnly(.remove(at: newIndex), to: changesOut)
        default:
            print("skipping \(change)")
            ()
        }
        let newLatest = latest.applying(change)
        return remainder.read(target: target) { value in
            return filterH(target: target, changesOut: changesOut, changesIn: value, condition: condition, latest: newLatest)
        }

    }
}
extension ArrayWithHistory {
    var unsafeLatestSnapshot: [A] {
        var result: [A] = initial
        var x = changes
        while case let .cons(change, tail) = x.value! {
            result.apply(change)
            x = tail
        }
        return result
    }

    public var latest: I<[A]> {
        return changes.flatMap(eq: ==) { (changes: IList<ArrayChange<A>>) -> I<[A]> in
            return changes.reduce(eq: ==, initial: self.initial) { (change, r) in
                r.applying(change)
            }
        }
    }

    public func filter(condition: I<(A) -> Bool>) -> I<ArrayWithHistory<A>> {
        var previousCondition: (A) -> Bool = condition.value
        let result: I<ArrayWithHistory<A>> = I(value: ArrayWithHistory(unsafeLatestSnapshot.filter(previousCondition)))
        let resultChanges = result.value.changes
        var previous: Disposable? = nil
        condition.read(target: result) { c in
            previous = nil
            let filterChanges = self.unsafeLatestSnapshot.filterChanges(oldCondition: previousCondition, newCondition: c)
            previousCondition = c
            concatOnly(filterChanges, to: resultChanges)
            let target = I<()>(eq: { _, _ in true}) // phantom target
            // when a new change comes in, we need to check if it matches the new condition, if yes, propagate. we only are interested in *new* changes, that is, changes appended to tail
            let (node,disposable) = tail(self.changes).read { (newChanges: IList<ArrayChange<A>>) in
                return filterH(target: target, changesOut: resultChanges, changesIn: newChanges, condition: c, latest: self.unsafeLatestSnapshot)
            }
            let token = result.strongReferences.add(disposable)
            previous = Disposable {
                result.strongReferences.remove(token)
            }
            return node
        }
        return result
    }
}
//
//let sample = ArrayWithHistory<Int>([1,2,3])
