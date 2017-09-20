import Incremental

let x = Input(1)
let y = Input(100)
let result = x.i.flatMap { value -> I<Int> in
    print("flatMap: \(value))")
    if value < 2 {
        return x.i
    } else {
        return y.i
    }
}
let disposable = result.observe { print($0) }
let disposable2 = x.i.observe { print("x: \($0)") }

x.write(3)

x.i.value
