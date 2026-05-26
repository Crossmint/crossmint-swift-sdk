import Foundation

public struct OTPFlow: Sendable, Identifiable {
    public enum Signer: Sendable {
        case email(String)

        var locator: String {
            switch self {
            case .email(let address): "email:\(address)"
            }
        }
    }

    public let signer: Signer
    public let sendOTP: @Sendable () async throws -> Void
    public let verifyOTP: @Sendable (_ code: String) async throws -> Void
    public let cancel: @Sendable () -> Void

    public let id = UUID()
}
