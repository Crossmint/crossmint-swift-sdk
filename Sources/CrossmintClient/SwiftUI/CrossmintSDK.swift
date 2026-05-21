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

    @MainActor public static func configure(apiKey: String, logLevel: LogLevel = .error) {
        guard _shared == nil else {
            Logger.sdk.warn("CrossmintSDK.configure() called after SDK is already configured — ignoring")
            return
        }
        Logger.level = logLevel
        _shared = CrossmintSDK(apiKey: apiKey)
    }

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

    public func setJWT(_ jwt: String) async {
        await authManager.setJWT(jwt)
    }

    private init(apiKey: String) {
        sdkInstances += 1
        if sdkInstances > 1 {
            Logger.sdk.error("Multiple SDK instances created, behaviour is undefined")
        }

        do {
            sdk = try CrossmintClient.sdk(key: apiKey)
            let authManager = sdk.authManager
            self.crossmintWallets = sdk.crossmintWallets()
            self.authManager = authManager
            self.crossmintService = sdk.crossmintService
            self.crossmintTEE = CrossmintTEE.start(
                auth: authManager,
                webProxy: DefaultWebViewCommunicationProxy(),
                apiKey: apiKey,
                isProductionEnvironment: sdk.crossmintService.isProductionEnvironment
            )
        } catch {
            Logger.client.error("Invalid Crossmint API key provided: \(error)")
            fatalError("Invalid Crossmint API key provided. Please verify your API key is a valid client key.")
        }
    }

    public func logout() async throws {
        _ = try? await authManager.logout()
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
