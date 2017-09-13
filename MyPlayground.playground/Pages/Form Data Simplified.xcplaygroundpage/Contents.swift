struct FormData {
    var name: String = ""
    var password: String = ""
    var passwordRepeat: String = ""
    
    var isValid: Bool {
        return !name.isEmpty && !password.isEmpty && password == passwordRepeat
    }
}

var data = FormData() {
    didSet {
        print("valid: \(data.isValid)")
    }
}

data.name = "Chris"
data.password = "Hi"
data.passwordRepeat = "Hi"
