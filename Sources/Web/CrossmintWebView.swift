import Logger
import SwiftUI
import WebKit

public struct CrossmintWebView: UIViewRepresentable {
    public let content: CrossmintWebViewContent?
    public let onWebViewMessage: (any WebViewMessage) -> Void
    public let onUnknownMessage: (String, Data) -> Void
    public let webViewCommunicationProxy: any WebViewCommunicationProxy
    private let bundleId: String?

    public init(
        webViewCommunicationProxy: (any WebViewCommunicationProxy)? = nil,
        onWebViewMessage: @escaping (any WebViewMessage) -> Void = { _ in },
        onUnknownMessage: @escaping (String, Data) -> Void = { _, _ in }
    ) {
        self.content = nil
        self.webViewCommunicationProxy = webViewCommunicationProxy ?? DefaultWebViewCommunicationProxy()
        self.onWebViewMessage = onWebViewMessage
        self.onUnknownMessage = onUnknownMessage
        self.bundleId = Bundle.main.bundleIdentifier
    }

    public init(
        url: URL,
        webViewCommunicationProxy: (any WebViewCommunicationProxy)? = nil,
        onWebViewMessage: @escaping (any WebViewMessage) -> Void = { _ in },
        onUnknownMessage: @escaping (String, Data) -> Void = { _, _ in }
    ) {
        self.init(content: .url(url), webViewCommunicationProxy: webViewCommunicationProxy, onWebViewMessage: onWebViewMessage, onUnknownMessage: onUnknownMessage)
    }

    public init(
        content: CrossmintWebViewContent? = nil,
        webViewCommunicationProxy: (any WebViewCommunicationProxy)? = nil,
        onWebViewMessage: @escaping (any WebViewMessage) -> Void = { _ in },
        onUnknownMessage: @escaping (String, Data) -> Void = { _, _ in }
    ) {
        self.content = content
        self.webViewCommunicationProxy = webViewCommunicationProxy ?? DefaultWebViewCommunicationProxy()
        self.onWebViewMessage = onWebViewMessage
        self.onUnknownMessage = onUnknownMessage
        self.bundleId = Bundle.main.bundleIdentifier
    }

    public func makeUIView(context: Context) -> WKWebView {
        if let existingWebView = webViewCommunicationProxy.webView {
            webViewCommunicationProxy.onWebViewMessage = onWebViewMessage
            webViewCommunicationProxy.onUnknownMessage = onUnknownMessage
            return existingWebView
        }

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
        webViewCommunicationProxy.onWebViewMessage = onWebViewMessage
        webViewCommunicationProxy.onUnknownMessage = onUnknownMessage
    }
}
