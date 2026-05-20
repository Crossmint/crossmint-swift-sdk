import Foundation

public struct OTPFlow: Sendable, Identifiable {
    public enum Signer: Sendable {
        case email(String)
        case phone(String)

        var locator: String {
            switch self {
            case .email(let addr): "email:\(addr)"
            case .phone(let num): "phone:\(num)"
            }
        }
    }

    public let signer: Signer
    public let sendOTP: @Sendable () async throws -> Void
    public let verifyOTP: @Sendable (_ code: String) async throws -> Void
    public let cancel: @Sendable () -> Void

    public var id: String { signer.locator }
}
