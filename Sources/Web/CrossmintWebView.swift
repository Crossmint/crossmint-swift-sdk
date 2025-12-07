import Logger
import SwiftUI
import WebKit

public struct CrossmintWebView: UIViewRepresentable {
    public let content: URL?
    public let webViewCommunicationProxy: any WebViewCommunicationProxy
    private let bundleId: String?

    public init(
        webViewCommunicationProxy: (any WebViewCommunicationProxy)? = nil
    ) {
        self.content = nil
        self.webViewCommunicationProxy = webViewCommunicationProxy ?? DefaultWebViewCommunicationProxy()
        self.bundleId = Bundle.main.bundleIdentifier
    }

    public init(
        content: URL? = nil,
        webViewCommunicationProxy: (any WebViewCommunicationProxy)? = nil
    ) {
        self.content = content
        self.webViewCommunicationProxy = webViewCommunicationProxy ?? DefaultWebViewCommunicationProxy()
        self.bundleId = Bundle.main.bundleIdentifier
    }

    public func makeUIView(context: Context) -> WKWebView {
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
        webViewCommunicationProxy.resetLoadedContent()

        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
    }
}
