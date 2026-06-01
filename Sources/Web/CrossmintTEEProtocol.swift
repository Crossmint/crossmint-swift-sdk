import Combine
import Foundation

// Minimum surface that email signers and CrossmintSDK need from a TEE implementation.
// CrossmintTEE (WebView) and NativeCrossmintTEE both conform to this so the rest of
// the SDK is agnostic to which implementation is active.
@MainActor
public protocol CrossmintTEEProtocol: AnyObject {
    var email: String? { get set }
    var isOTPRequired: Bool { get }
    // Publisher used by CrossmintSDK to bridge into SwiftUI.
    var isOTPRequiredPublisher: AnyPublisher<Bool, Never> { get }

    func signTransaction(transaction: String, keyType: String, encoding: String) async throws -> String
    func provideOTP(_ code: String)
    func cancelOTP()
    func load() async throws
    func resetState()
}
