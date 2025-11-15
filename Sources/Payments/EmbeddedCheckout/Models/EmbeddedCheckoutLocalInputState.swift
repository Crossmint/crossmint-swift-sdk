public struct EmbeddedCheckoutLocalInputState: Equatable {
    public var value: String
    public var errorMessage: String?

    public init(value: String, errorMessage: String?) {
        self.value = value
        self.errorMessage = errorMessage
    }
}
