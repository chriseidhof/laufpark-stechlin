import Incremental_Mac

var arr: ArrayWithHistory<Int> = ArrayWithHistory([1,2,3] as [Int])
let condition = Input<(Int) -> Bool>({ $0 % 2 == 0 }, eq: { _, _ in false })
let result: I<ArrayWithHistory<Int>> = arr.filter(condition: condition.i)
////let t: I<[Int]> =
let disposable2 = result.flatMap(eq: ==, { $0.latest }).observe {
    print("filtered: \($0)")
}
//let disposable1 = arr.latest.observe {
//    print("original: \($0)")
//    print("changes: \(arr.changes.value)")
//    print("filtered changes: \(result.value.changes.value)")
//}

arr.change(.insert(4, at: 3))
arr.change(.insert(5, at: 2))

condition.write { $0 > 1 }
//condition.write { $0 % 2 == 0 }
arr.change(.insert(6, at: 0))
//condition.write { $0 > 1 }
