import Incremental_Mac

var arr: ArrayWithHistory<Int> = ArrayWithHistory([1,2,3] as [Int])
let condition = Input<(Int) -> Bool>({ $0 % 2 == 0 }, eq: { _, _ in false })
let result: I<ArrayWithHistory<Int>> = arr.filter(condition: condition.i)
let disposable2 = result.flatMap(eq: ==, { $0.latest }).observe {
    print("filtered: \($0)")
}
print("1---")
arr.change(.insert(4, at: 3))
print("2---")
condition.write { $0 > 1 }
print("3---")
arr.change(.insert(6, at: 3))
arr.change(.insert(5, at: 3))
condition.write { $0 > 3 }
condition.write { $0 > 0 }
arr.change(.remove(at: 4))


// why is 6 in there twice?!

