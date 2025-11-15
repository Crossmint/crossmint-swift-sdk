public struct UnknownApiTransaction: TransactionApiModel {
    public var id: String = "unknown"

    public func toDomain(withService service: any SmartWalletService) -> Transaction? {
        nil
    }
}
