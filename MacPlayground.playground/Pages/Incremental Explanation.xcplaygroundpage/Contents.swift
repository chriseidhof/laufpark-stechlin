import Incremental_Mac

var arr: ArrayWithHistory<Int> = ArrayWithHistory([1,2,3] as [Int])
let condition = Input<(Int) -> Bool>(alwaysPropagate: { $0 % 2 == 0 })
let result: ArrayWithHistory<Int> = arr.filter(condition.i)
let disposable2 = result.latest.observe {
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
