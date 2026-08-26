import CrossmintAuth
import Combine
@_exported import CrossmintCommonTypes
import CrossmintService
import Logger
import SwiftUI
import Utils
@_exported import Wallet
import Web

@MainActor private var sdkInstances = 0

/// Entry point for the Crossmint SDK.
///
/// Call ``configure(apiKey:logLevel:trackingConsent:)`` once at app startup before accessing ``shared``.
/// Accessing ``shared`` before configuring causes a `fatalError`.
///
/// When using an email OTP signer, observe ``isOTPRequired`` to know when to display an OTP input,
/// then call ``submit(otp:)`` with the code the user enters.
///
/// ## Example
/// ```swift
/// @main
/// struct MyApp: App {
///     init() {
///         CrossmintSDK.configure(apiKey: "ck_development_...", logLevel: .warn, trackingConsent: .granted)
///     }
///
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .environmentObject(CrossmintSDK.shared)
///         }
///     }
/// }
/// ```
@MainActor
final public class CrossmintSDK: ObservableObject {
    @MainActor private static var _shared: CrossmintSDK?

    /// The configured SDK instance. Access after calling ``configure(apiKey:logLevel:)``.
    @MainActor public static var shared: CrossmintSDK {
        guard let instance = _shared else {
            fatalError(
                "CrossmintSDK is not configured. " +
                "Call CrossmintSDK.configure(apiKey:) before accessing CrossmintSDK.shared."
            )
        }
        return instance
    }

    /// Configures the SDK. Must be called once before accessing ``shared``.
    ///
    /// Subsequent calls are silently ignored — the SDK can only be configured once per process.
    ///
    /// - Parameters:
    ///   - apiKey: A client API key (prefixed `ck_`).
    ///   - logLevel: Controls SDK log verbosity. Defaults to `.error`.
    ///   - trackingConsent: Whether the SDK may send remote logs. Local `os.log` output is unaffected.
    @MainActor public static func configure(
        apiKey: String,
        logLevel: LogLevel = .error,
        trackingConsent: TrackingConsent
    ) {
        guard _shared == nil else {
            Logger.sdk.warning("CrossmintSDK.configure() called after SDK is already configured — ignoring")
            return
        }
        Logger.level = logLevel
        _shared = CrossmintSDK(apiKey: apiKey, trackingConsent: trackingConsent)
    }

    private let sdk: ClientSDK

    /// Factory for creating and retrieving smart wallets. See ``CrossmintWallets``.
    public let crossmintWallets: CrossmintWallets
    /// Authentication manager for the email OTP flow. See ``CrossmintAuthManager``.
    public let authManager: CrossmintAuthManager
    /// Low-level Crossmint service for direct API access.
    public let crossmintService: CrossmintService
    /// Standalone auth client for explicit OTP lifecycle management. See ``AuthClient``.
    public let authClient: AuthClient

    let crossmintTEE: CrossmintTEE

    /// Emits `true` when a pending transaction is waiting for the user to enter an email OTP.
    public var isOTPRequired: Published<Bool>.Publisher {
        crossmintTEE.$isOTPRequired
    }

    /// Provides the OTP entered by the user to unblock the pending transaction.
    public func submit(otp: String) {
        crossmintTEE.provideOTP(otp)
    }

    /// Cancels the pending transaction waiting for an OTP.
    public func cancelTransaction() {
        crossmintTEE.cancelOTP()
    }

    /// Whether the SDK is running against the Crossmint production environment.
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

    private init(apiKey: String, trackingConsent: TrackingConsent) {
        sdkInstances += 1
        if sdkInstances > 1 {
            Logger.sdk.error("Multiple SDK instances created, behaviour is undefined")
        }

        DataDogConfig.setTrackingConsent(trackingConsent)

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
        self.authClient = innerSdk.authClient
        crossmintService = innerSdk.crossmintService
        crossmintTEE = CrossmintTEE.start(
            auth: authManager,
            webProxy: DefaultWebViewCommunicationProxy(),
            apiKey: apiKey,
            isProductionEnvironment: innerSdk.crossmintService.isProductionEnvironment
        )
    }

    /// Sets or updates the tracking consent for remote logging
    /// - Parameter consent: The new tracking consent state
    /// - Note: When changing from pending to granted, all batched data will be sent.
    ///         When changing from pending to notGranted, all batched data will be wiped.
    ///         This only affects remote logs; local os.log entries will continue to be displayed.
    public func setTrackingConsent(_ consent: TrackingConsent) {
        DataDogConfig.setTrackingConsent(consent)
    }

    /// Invalidates the server-side refresh token, clears the local session, and resets OTP state.
    public func logout() async {
        do {
            _ = try await authManager.logout()
        } catch {
            Logger.sdk.warning("Logout request failed: \(error) — clearing local state anyway")
        }
        await authClient.logout()
        crossmintTEE.resetState()
    }

    deinit {
        Task { @MainActor in
            sdkInstances -= 1
        }
    }
}
