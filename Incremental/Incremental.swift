import Foundation

// This class is (by design) not thread-safe
final class Queue {
    static let shared = Queue()
    var edges: [(Edge, Height)] = []
    var processed: [Edge] = []
    var fired: [AnyI] = []
    var processing: Bool = false
    
    func enqueue<S: Sequence>(_ edges: S) where S.Element: Edge {
        self.edges.append(contentsOf: edges.map { ($0, $0.height) })
        self.edges.sort { $0.1 < $1.1 }
    }
    
    func fired(_ source: AnyI) {
        fired.append(source)
    }
    
    func process() {
        guard !processing else { return }
        processing = true
        while let (edge, _) = edges.popLast() {
            guard !processed.contains(where: { $0 === edge }) else {
                continue
            }
            processed.append(edge)
            edge.fire()
        }
        
        // cleanup
        for i in fired {
            i.firedAlready = false
        }
        fired = []
        processed = []
        processing = false
    }
}

protocol Node {
    var height: Height { get }
}

protocol Edge: class, Node {
    func fire()
}

final class Observer: Edge {
    let observer: () -> ()
    
    init(_ fire: @escaping  () -> ()) {
        self.observer = fire
        fire()
    }
    let height = Height.minusOne
    func fire() {
        observer()
    }
}

class Reader: Node, Edge {
    let read: () -> Node
    var height: Height {
        return target.height.incremented()
    }
    var target: Node
    var invalidated: Bool = false
    init(read: @escaping () -> Node) {
        self.read = read
        target = read()
    }
    
    func fire() {
        if invalidated {
            return
        }
        target = read()
    }
}


public final class Input<A> {
    public let i: I<A>
    
    public init(_ value: A, eq: @escaping (A,A) -> Bool) {
        i = I(value: value, eq: eq)
    }
    
    public func write(_ newValue: A) {
        i.write(newValue)
    }
    
    public func change(_ by: (inout A) -> ()) {
        var copy = i.value!
        by(&copy)
        i.write(copy)
    }    
}

public extension Input where A: Equatable {
    public convenience init(_ value: A) {
        self.init(value, eq: ==)
    }
}


protocol AnyI: class {
    var firedAlready: Bool { get set }
    var strongReferences: Register<Any> { get set }
}

public final class I<A>: AnyI, Node {
    internal(set) public var value: A! // todo this will not be public!
    var observers = Register<Observer>()
    var readers: Register<Reader> = Register()
    var height: Height {
        return readers.values.map { $0.height }.lub.incremented()
    }
    var firedAlready: Bool = false
    var strongReferences: Register<Any> = Register()
    var eq: (A,A) -> Bool
    private let constant: Bool
    
    init(value: A, eq: @escaping (A, A) -> Bool) {
        self.value = value
        self.eq = eq
        self.constant = false
    }

    fileprivate init(eq: @escaping (A,A) -> Bool) {
        self.eq = eq
        self.constant = false
    }
    
    public init(constant: A) {
        self.value = constant
        self.eq = { _, _ in true }
        self.constant = true
    }
    
    public func observe(_ observer: @escaping (A) -> ()) -> Disposable {
        let token = observers.add(Observer {
            observer(self.value)
        })
        return Disposable { /* should this be weak/unowned? */
            self.observers.remove(token)
        }
    }
    
    /// Returns `self`
    @discardableResult
    func write(_ value: A) -> I<A> {
        assert(!constant)
        if let existing = self.value, eq(existing, value) { return self }
        
        self.value = value
        guard !firedAlready else { return self }
        firedAlready = true
        Queue.shared.enqueue(readers.values)
        Queue.shared.enqueue(observers.values)
        Queue.shared.fired(self)
        Queue.shared.process()
        return self
    }
    
    func read(_ read: @escaping (A) -> Node) -> (Reader, Disposable) {
        let reader = Reader(read: {
            read(self.value)
        })
        if constant {
            return (reader, Disposable { })
        }
        let token = readers.add(reader)
        return (reader, Disposable {
            self.readers[token]?.invalidated = true
            self.readers.remove(token)
        })
    }
    
    @discardableResult
    func read(target: AnyI, _ read: @escaping (A) -> Node) -> Reader {
        let (reader, disposable) = self.read(read)
        target.strongReferences.add(disposable)
        return reader
    }

    public func map<B>(eq: @escaping (B,B) -> Bool, _ transform: @escaping (A) -> B) -> I<B> {
        let result = I<B>(eq: eq)
        read(target: result) { value in
            result.write(transform(value))
        }
        return result
    }
    
    public func flatMap<B: Equatable>(_ transform: @escaping (A) -> I<B>) -> I<B> {
        let result = I<B>(eq: ==)
        var previous: Disposable?
        // todo: we might be able to avoid this closure by having a custom "flatMap" reader
        read(target: result) { value in
            previous = nil
            let (reader, disposable) = transform(value).read { value2 in
                result.write(value2)
            }
            let token = result.strongReferences.add(disposable)
            previous = Disposable { result.strongReferences.remove(token) }
            return reader
        }
        return result
    }
    
    func mutate(_ transform: (inout A) -> ()) {
        var newValue = value!
        transform(&newValue)
        write(newValue)
    }
}

extension I {
    public func zip2<B: Equatable,C: Equatable>(_ other: I<B>, _ with: @escaping (A,B) -> C) -> I<C> {
        return flatMap { value in other.map { with(value, $0) } }
    }
    
    public func zip3<B: Equatable,C: Equatable,D: Equatable>(_ x: I<B>, _ y: I<C>, _ with: @escaping (A,B,C) -> D) -> I<D> {
        return flatMap { value1 in
            x.flatMap { value2 in
                y.map { with(value1, value2, $0) }
            }
        }
    }
    
    // convenience for equatable
    public func map<B: Equatable>(_ transform: @escaping (A) -> B) -> I<B> {
        return map(eq: ==, transform)
    }
    
    // convenience for optionals
    public func map<B: Equatable>(_ transform: @escaping (A) -> B?) -> I<B?> {
        return map(eq: ==, transform)
    }
    
    // convenience for arrays
    public func map<B: Equatable>(_ transform: @escaping (A) -> [B]) -> I<[B]> {
        return map(eq: ==, transform)
    }
}

extension I where A: Equatable {
    convenience init(value: A) {
        self.init(value: value, eq: ==)
    }
}
