import Incremental

struct FormData {
    let name = Var("")
    let password = Var("")
    let passwordRepeat = Var("")
    
    let isValid: I<Bool>
    
    init() {
        let validName = name.i.map { !$0.isEmpty }
        let validPassword = password.i.map { !$0.isEmpty }
        let isRepeated: I<Bool> = password.i == passwordRepeat.i
        isValid = validName && validPassword && isRepeated
    }
}

var data = FormData()
let observer = data.isValid.observe {
    print($0)
}
data.name.set("Chris")
data.password.set("Hi")
data.passwordRepeat.set("Hi")

