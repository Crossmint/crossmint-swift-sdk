import CrossmintAuth
import Combine
@_exported import CrossmintCommonTypes
@_exported import CrossmintService
import Logger
import SwiftUI
import Utils
@_exported import Wallet
import Web

@MainActor private var sdkInstances = 0

@MainActor
final public class CrossmintSDK: ObservableObject {
    @MainActor private static var _shared: CrossmintSDK?

    @MainActor public static var shared: CrossmintSDK {
        guard let instance = _shared else {
            fatalError(
                "CrossmintSDK is not configured. " +
                "Call CrossmintSDK.configure(apiKey:) before accessing CrossmintSDK.shared."
            )
        }
        return instance
    }

    /// Configures the SDK with the given API key. Must be called before accessing `CrossmintSDK.shared`.
    /// Subsequent calls are ignored — the SDK can only be configured once per process.
    @MainActor public static func configure(apiKey: String, logLevel: LogLevel = .error) {
        guard _shared == nil else {
            Logger.sdk.warn("CrossmintSDK.configure() called after SDK is already configured — ignoring")
            return
        }
        Logger.level = logLevel
        _shared = CrossmintSDK(apiKey: apiKey)
    }

    private let sdk: ClientSDK

    public let crossmintWallets: CrossmintWallets
    public let authManager: CrossmintAuthManager
    public let crossmintService: CrossmintService

    let crossmintTEE: CrossmintTEE

    public var isOTPRequired: Published<Bool>.Publisher {
        crossmintTEE.$isOTPRequired
    }
    public func submit(otp: String) {
        crossmintTEE.provideOTP(otp)
    }
    public func cancelTransaction() {
        crossmintTEE.cancelOTP()
    }

    public var isProductionEnvironment: Bool {
        crossmintService.isProductionEnvironment
    }

    /// Sets a JWT for authentication. Use this when authenticating with an externally obtained token
    /// rather than through the built-in OTP flow.
    ///
    /// - Note: Unlike the TypeScript SDK's synchronous `setJwt`, this is `async` because it
    ///   updates actor-isolated state on `CrossmintAuthManager`.
    public func setJWT(_ jwt: String) async {
        await authManager.setJWT(jwt)
    }

    private init(apiKey: String) {
        sdkInstances += 1
        if sdkInstances > 1 {
            Logger.sdk.error("Multiple SDK instances created, behaviour is undefined")
        }

        let innerSdk: ClientSDK
        do {
            innerSdk = try CrossmintClient.sdk(key: apiKey)
        } catch {
            Logger.client.error("Invalid Crossmint API key provided: \(error)")
            fatalError("Invalid Crossmint API key provided. Please verify your API key is a valid client key.")
        }

        let authManager = innerSdk.authManager
        sdk = innerSdk
        crossmintWallets = innerSdk.crossmintWallets()
        self.authManager = authManager
        crossmintService = innerSdk.crossmintService
        crossmintTEE = CrossmintTEE.start(
            auth: authManager,
            webProxy: DefaultWebViewCommunicationProxy(),
            apiKey: apiKey,
            isProductionEnvironment: innerSdk.crossmintService.isProductionEnvironment
        )
    }

    public func logout() async {
        do {
            _ = try await authManager.logout()
        } catch {
            Logger.sdk.warn("Logout request failed: \(error) — clearing local state anyway")
        }
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
