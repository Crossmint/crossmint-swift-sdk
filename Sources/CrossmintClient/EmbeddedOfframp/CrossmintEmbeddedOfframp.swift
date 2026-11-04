import CrossmintService
import Foundation
import SwiftUI
import Utils
import Web
import WebKit

/// A view that runs one Crossmint offramp session: the user adds a bank account, gets a quote, verifies their
/// identity when the session needs it, and confirms one deposit that the payer signs and sends. The view then
/// follows the payout.
///
/// The view uses the client API key that ``CrossmintSDK/configure(apiKey:logLevel:)`` received.
/// Attach event handlers with ``onReady(_:)``, ``onStatusChange(_:)``, ``onComplete(_:)``, ``onCancel(_:)``,
/// and ``onError(_:)``.
///
/// The view takes the height of the page, unless `fill` is `true`. A change to the credentials, the appearance, the
/// locale, `fill`, or to whether the payer has `signMessage` reloads the page. The payer and the handlers can change
/// without a reload.
///
/// Identity verification uses the camera. Add `NSCameraUsageDescription` to your app's Info.plist.
///
/// ## Example
///
/// ```swift
/// // Your server creates the offramp session and returns its credentials.
/// let credentials = EmbeddedOfframpCredentials(sessionId: session.sessionId, clientSecret: session.clientSecret)
///
/// CrossmintEmbeddedOfframp(
///     credentials: credentials,
///     payer: EmbeddedOfframpPayer(signAndSendTransaction: { transaction in
///         try await myWallet.signAndSend(transaction.serializedTransaction, on: transaction.chain)
///     })
/// )
/// .onComplete { completion in print("Deposit sent: \(completion.txId)") }
/// .onCancel { dismiss() }
/// ```
public struct CrossmintEmbeddedOfframp: View {
    let credentials: EmbeddedOfframpCredentials
    let payer: EmbeddedOfframpPayer
    private let appearance: (any Encodable)?
    private let locale: OfframpLocale?
    private let fill: Bool
    var onReadyHandler: (() -> Void)?
    var onStatusChangeHandler: ((OfframpStatusChange) -> Void)?
    var onCompleteHandler: ((OfframpCompletion) -> Void)?
    var onCancelHandler: (() -> Void)?
    var onErrorHandler: ((OfframpError) -> Void)?
    // Until the page reports its own height. WebKit may throttle a page that has no height.
    @State private var height: CGFloat = 500

    /// Creates an offramp view.
    ///
    /// - Parameters:
    ///   - credentials: The credentials of the offramp session.
    ///   - payer: Signs and sends the deposit from your wallet.
    ///   - appearance: Fonts, colors and styles, encoded as the JSON `appearance` object of the
    ///     [offramp UI customization guide](https://docs.crossmint.com/offramp/guides/ui-customization).
    ///   - locale: The language of the screens. A `nil` value uses the device language, else English.
    ///   - fill: Fills the height that the layout gives the view instead of taking the height of the page.
    public init(
        credentials: EmbeddedOfframpCredentials,
        payer: EmbeddedOfframpPayer,
        appearance: (any Encodable)? = nil,
        locale: OfframpLocale? = nil,
        fill: Bool = false
    ) {
        self.credentials = credentials
        self.payer = payer
        self.appearance = appearance
        self.locale = locale
        self.fill = fill
    }

    /// Adds an action to perform when the first screen shows. It runs once per load.
    public func onReady(_ action: @escaping () -> Void) -> Self {
        var view = self
        view.onReadyHandler = action
        return view
    }

    /// Adds an action to perform when the flow moves to another step.
    public func onStatusChange(_ action: @escaping (OfframpStatusChange) -> Void) -> Self {
        var view = self
        view.onStatusChangeHandler = action
        return view
    }

    /// Adds an action to perform when the deposit is confirmed. It can run again for a reopened withdrawal,
    /// so deduplicate by `orderId`.
    public func onComplete(_ action: @escaping (OfframpCompletion) -> Void) -> Self {
        var view = self
        view.onCompleteHandler = action
        return view
    }

    /// Adds an action to perform when the user closes the flow. Without it, the Continue, Close and Cancel buttons
    /// do nothing.
    public func onCancel(_ action: @escaping () -> Void) -> Self {
        var view = self
        view.onCancelHandler = action
        return view
    }

    /// Adds an action to perform when something goes wrong.
    public func onError(_ action: @escaping (OfframpError) -> Void) -> Self {
        var view = self
        view.onErrorHandler = action
        return view
    }

    public var body: some View {
        let sdk = CrossmintSDK.shared
        if let apiBaseURL = try? sdk.crossmintService.getApiBaseURL(),
           let page = pageURL(apiKey: sdk.apiKey.key, apiBaseURL: apiBaseURL) {
            OfframpWebView(page: page, offramp: self, height: $height)
                .frame(height: fill ? nil : height)
                // A new page must never receive the reply to a wallet request of the previous one.
                .id(page)
        } else {
            Color.clear.onAppear {
                onErrorHandler?(OfframpError(
                    reason: .invalidConfiguration, retriable: false,
                    message: "The offramp page URL cannot be built. Check that the appearance encodes as JSON"
                ))
            }
        }
    }

    func pageURL(apiKey: String, apiBaseURL: URL) -> URL? {
        var query = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "credentials", value: Self.json(credentials)),
            URLQueryItem(name: "sdkMetadata", value: Self.json([
                "name": "crossmint-swift-sdk",
                "version": SDKVersion.version
            ]))
        ]
        if let appearance {
            guard let json = Self.json(appearance) else { return nil }
            query.append(URLQueryItem(name: "appearance", value: json))
        }
        if let locale {
            query.append(URLQueryItem(name: "locale", value: locale.rawValue))
        }
        if fill {
            query.append(URLQueryItem(name: "fill", value: "true"))
        }
        if payer.signMessage != nil {
            query.append(URLQueryItem(name: "canSignMessage", value: "true"))
        }
        guard var components = URLComponents(url: apiBaseURL, resolvingAgainstBaseURL: false) else { return nil }
        components.path = "/sdk/unstable/embedded-offramp"
        components.queryItems = query
        // The page reads the query with URLSearchParams, which turns a literal + into a space.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    private static func json(_ value: some Encodable) -> String? {
        let encoder = JSONEncoder()
        // Stable key order keeps the page URL, and so the view identity, the same across updates.
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

struct OfframpWebView: UIViewRepresentable {
    static let handlerName = "crossmintOfframp"

    let page: URL
    let offramp: CrossmintEmbeddedOfframp
    @Binding var height: CGFloat

    func makeCoordinator() -> EmbeddedOfframpBridge {
        EmbeddedOfframpBridge(host: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(
            source: CrossmintJavaScriptBridge.communicationScript(bundleID: nil, handlerName: Self.handlerName),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        configuration.userContentController.add(context.coordinator, name: Self.handlerName)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        context.coordinator.reply = { [weak webView] message in
            webView?.callAsyncJavaScript(
                "window.onMessageFromNative(message)", arguments: ["message": message], in: nil, in: .page
            ) { _ in }
        }
        webView.load(URLRequest(url: page))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.host = self
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: EmbeddedOfframpBridge) {
        coordinator.reply = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: handlerName)
    }
}
