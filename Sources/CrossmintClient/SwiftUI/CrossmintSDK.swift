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
    nonisolated(unsafe) private static var _shared: CrossmintSDK?

    /// Returns the shared SDK instance.
    ///
    /// - Important: You must call `configure(with:)` before accessing this property.
    ///
    /// - Throws: Fatal error if the SDK has not been configured.
    public static var shared: CrossmintSDK {
        guard let _shared else {
            fatalError(
                "CrossmintSDK.configure(with:) must be called before accessing .shared. " +
                "Call CrossmintSDK.configure(with: Configuration(apiKey:)) in your app initialization."
            )
        }
        return _shared
    }

    /// Configures the SDK with the provided configuration.
    ///
    /// This method allows you to customize SDK behavior beyond the basic API key setup.
    ///
    /// Example:
    /// ```swift
    /// CrossmintSDK.configure(with: Configuration(
    ///     apiKey: "ck_staging_...",
    ///     logLevel: .debug
    /// ))
    /// ```
    ///
    /// - Parameter configuration: The SDK configuration.
    public static func configure(with configuration: Configuration) {
        if _shared != nil {
            Logger.sdk.warn("CrossmintSDK.configure() called multiple times. Ignoring subsequent calls.")
            return
        }

        Logger.level = configuration.logLevel
        let newInstance = CrossmintSDK(configuration: configuration)
        _shared = newInstance
    }

    private let sdk: ClientSDK

    /// The SDK configuration used to initialize this instance.
    public let configuration: Configuration

    public let crossmintWallets: CrossmintWallets
    public let authManager: AuthManager
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

    private init(configuration: Configuration) {
        sdkInstances += 1
        if sdkInstances > 1 {
            Logger.sdk.error("Multiple SDK instances created, behaviour is undefined")
        }

        self.configuration = configuration

        do {
            sdk = try CrossmintClient.sdk(key: configuration.apiKey, authManager: nil)
            let authManager = sdk.authManager
            self.crossmintWallets = sdk.crossmintWallets()
            self.authManager = authManager
            self.crossmintService = sdk.crossmintService
            self.crossmintTEE = CrossmintTEE.start(
                auth: authManager,
                webProxy: DefaultWebViewCommunicationProxy(),
                apiKey: configuration.apiKey,
                isProductionEnvironment: sdk.crossmintService.isProductionEnvironment
            )
        } catch {
            Logger.client.error("Invalid Crossmint API key provided: \(error)")
            fatalError("Invalid Crossmint API key provided. Please verify your API key is a valid client key.")
        }
    }

    public func logout() async throws {
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
