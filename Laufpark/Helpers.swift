//
//  Helpers.swift
//  Laufpark
//
//  Created by Chris Eidhof on 18.09.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation
import Incremental

extension Bool {
    mutating func toggle() {
        self = !self
    }
}

extension Comparable {
    func clamped(to: ClosedRange<Self>) -> Self {
        if self < to.lowerBound { return to.lowerBound }
        if self > to.upperBound { return to.upperBound }
        return self
    }
}

func time<Result>(name: StaticString = #function, line: Int = #line, _ f: () -> Result) -> Result {
    let startTime = DispatchTime.now()
    let result = f()
    let endTime = DispatchTime.now()
    let diff = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000 as Double
    print("\(name) (line \(line)): \(diff) sec")
    return result
}

var globalPersistentValues: [String:Any] = [:]

// Stores the state S in userDefaults under the provided key
func persistent<S: Equatable & Codable>(key: String, initial start: S) -> Input<S> {
    let defaults = UserDefaults.standard
    let initial = defaults.data(forKey: key).flatMap {
        let decoder = JSONDecoder()
        let result = try? decoder.decode(S.self, from: $0)
        return result
        } ?? start
    
    let input = Input<S>(initial)
    let encoder = JSONEncoder()
    let disposable = input.i.observe { value in
        let data = try! encoder.encode(value)
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }
    globalPersistentValues[key] = disposable
    return input
}
