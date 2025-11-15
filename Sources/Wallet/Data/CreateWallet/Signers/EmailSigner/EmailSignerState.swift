import CrossmintCommonTypes

actor EmailSignerState {
    var email: String?
    var isInitialized = false

    init() {
        self.email = nil
    }

    func update(email: String) {
        self.email = email
        isInitialized = true
    }
}
