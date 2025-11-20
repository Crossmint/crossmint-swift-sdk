import Foundation

public struct NonCustodialSignerCallback: Identifiable {
    public let id = UUID()
    public let otpCode: (String) -> Void
    public let otpCancelled: () -> Void

    public static var noOp: NonCustodialSignerCallback {
        NonCustodialSignerCallback(otpCode: { _ in }, otpCancelled: {})
    }
}
