import Logger
import SwiftUI
import WebKit

public struct CrossmintWebView: UIViewRepresentable {
    public let content: URL?
    public let onWebViewMessage: (any WebViewMessage) -> Void
    public let onUnknownMessage: (String, Data) -> Void
    public let tee: CrossmintTEE

    private let bundleId: String?
    private var webViewCommunicationProxy: WebViewCommunicationProxy {
        return tee.webProxy
    }

    public init(
        tee: CrossmintTEE,
        onWebViewMessage: @escaping (any WebViewMessage) -> Void = { _ in },
        onUnknownMessage: @escaping (String, Data) -> Void = { _, _ in }
    ) {
        self.content = nil
        self.tee = tee
        self.onWebViewMessage = onWebViewMessage
        self.onUnknownMessage = onUnknownMessage
        self.bundleId = Bundle.main.bundleIdentifier
    }

    public func makeUIView(context: Context) -> WKWebView {
        tee.resetState()
        Task { @MainActor in try? await tee.load() }

        let configuration = WKWebViewConfiguration()
        let userContentController = WKUserContentController()

        let communicationScript = WKUserScript(
            source: CrossmintJavaScriptBridge.communicationScript(bundleID: bundleId, handlerName: webViewCommunicationProxy.name),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(communicationScript)

        userContentController.add(webViewCommunicationProxy: webViewCommunicationProxy)

        configuration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = webViewCommunicationProxy
#if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
#endif
        webViewCommunicationProxy.webView = webView
        webViewCommunicationProxy.onWebViewMessage = onWebViewMessage
        webViewCommunicationProxy.onUnknownMessage = onUnknownMessage
        webViewCommunicationProxy.resetLoadedContent()

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
    }
}
