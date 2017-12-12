//
//  SortedArray.swift
//  Laufpark
//
//  Created by Chris Eidhof on 11.12.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

import Foundation

struct SortedArray<Element> {
    var elements: [Element]
    let isAscending: (Element, Element) -> Bool
    
    init<S: Sequence>(unsorted: S, isAscending: @escaping (Element, Element) -> Bool) where S.Iterator.Element == Element {
        elements = unsorted.sorted(by: isAscending)
        self.isAscending = isAscending
    }
    
    func index(for element: Element) -> Int {
        var start = elements.startIndex
        var end = elements.endIndex
        while start < end {
            let middle = start + (end - start) / 2
            if isAscending(elements[middle], element) {
                start = middle + 1
            } else {
                end = middle
            }
        }
        assert(start == end)
        return start
    }
    
    mutating func insert(_ element: Element) {
        elements.insert(element, at: index(for: element))
    }
    
    mutating func mutate(at index: Int, _ change: (inout Element) -> ()) {
        var value = elements.remove(at: index) // todo: could be more optimal?
        change(&value)
        insert(value)
    }
    
    mutating func popLast() -> Element? {
        return elements.popLast()
    }
    
    func index(of needle: Element, _ isEqual: (Element, Element) -> Bool) -> Int? {
        let i = index(for: needle)
        guard i < endIndex else { return nil }
        return isEqual(elements[i], needle) ? i : nil
    }
}

extension SortedArray where Element: Equatable {
    func contains(element: Element) -> Bool {
        let index = self.index(for: element)
        guard index < elements.endIndex else { return false }
        return self[index] == element
    }
}

extension SortedArray: Collection {
    var startIndex: Int {
        return elements.startIndex
    }
    
    var endIndex: Int {
        return elements.endIndex
    }
    
    subscript(index: Int) -> Element {
        return elements[index]
    }
    
    func index(after i: Int) -> Int {
        return elements.index(after: i)
    }
    
    func min() -> Element? {
        return elements.first
    }
}

