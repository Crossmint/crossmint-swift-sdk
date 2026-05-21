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
        #if DEBUG
        if _shared == nil, let envApiKey = ProcessInfo.processInfo.environment["CROSSMINT_API_KEY"] {
            Logger.client.info("Using API key from the environment variable.")
            configure(apiKey: envApiKey)
        }
        #endif
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

    /// Configures the SDK from a `Configuration` value. Must be called before accessing `CrossmintSDK.shared`.
    @MainActor public static func configure(with configuration: Configuration) {
        configure(apiKey: configuration.apiKey, logLevel: configuration.logLevel)
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
        let components = Self.makeComponents(apiKey: apiKey)
        sdk = components.sdk
        crossmintWallets = components.wallets
        authManager = components.authManager
        crossmintService = components.service
        crossmintTEE = components.tee
    }

    private struct Components {
        let sdk: ClientSDK
        let wallets: CrossmintWallets
        let authManager: CrossmintAuthManager
        let service: CrossmintService
        let tee: CrossmintTEE
    }

    private static func makeComponents(apiKey: String) -> Components {
        do {
            let sdk = try CrossmintClient.sdk(key: apiKey)
            let authManager = sdk.authManager
            return Components(
                sdk: sdk,
                wallets: sdk.crossmintWallets(),
                authManager: authManager,
                service: sdk.crossmintService,
                tee: CrossmintTEE.start(
                    auth: authManager,
                    webProxy: DefaultWebViewCommunicationProxy(),
                    apiKey: apiKey,
                    isProductionEnvironment: sdk.crossmintService.isProductionEnvironment
                )
            )
        } catch {
            Logger.client.error("Invalid Crossmint API key provided: \(error)")
            fatalError("Invalid Crossmint API key provided. Please verify your API key is a valid client key.")
        }
    }

    public func logout() async {
        _ = try? await authManager.logout()
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
