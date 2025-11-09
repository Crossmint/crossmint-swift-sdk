public struct NonCustodialSignerCallback {
    public let otpCode: (String) -> Void
    public let otpCancelled: () -> Void

    public static var noOp: NonCustodialSignerCallback {
        NonCustodialSignerCallback(otpCode: { _ in }, otpCancelled: {})
    }
}
