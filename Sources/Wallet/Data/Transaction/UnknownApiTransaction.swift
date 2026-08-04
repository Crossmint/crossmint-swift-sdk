public struct UnknownApiTransaction: TransactionApiModel {
    public var id: String = "unknown"

    public func toDomain() -> Transaction? {
        nil
    }
}
