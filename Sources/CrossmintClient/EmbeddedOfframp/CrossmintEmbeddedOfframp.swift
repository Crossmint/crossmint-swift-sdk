import SwiftUI
import WebKit

/// The host must provide NSCameraUsageDescription and NSMicrophoneUsageDescription for in-page KYC.
@MainActor
public struct CrossmintEmbeddedOfframp: View {
    private let configuration: EmbeddedOfframpConfiguration
    private let payer: @MainActor (OfframpTransaction) async throws -> String
    private let callbacks: EmbeddedOfframpCallbacks

    public init(
        configuration: EmbeddedOfframpConfiguration,
        payer: @escaping @MainActor (OfframpTransaction) async throws -> String,
        callbacks: EmbeddedOfframpCallbacks = .init()
    ) {
        self.configuration = configuration
        self.payer = payer
        self.callbacks = callbacks
    }

    public var body: some View {
        OfframpWebView(configuration: configuration, payer: payer, callbacks: callbacks)
            // A changed session gets a new bridge so an old wallet reply cannot reach its page.
            .id(configuration.url)
    }
}

@MainActor
struct OfframpWebView: UIViewRepresentable {
    let configuration: EmbeddedOfframpConfiguration
    let payer: @MainActor (OfframpTransaction) async throws -> String
    let callbacks: EmbeddedOfframpCallbacks

    func makeCoordinator() -> Coordinator {
        Coordinator(bridge: EmbeddedOfframpBridge(configuration: configuration, payer: payer, callbacks: callbacks))
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "crossmintOfframp")
        config.userContentController.addUserScript(WKUserScript(
            source: Self.script, injectionTime: .atDocumentStart, forMainFrameOnly: true
        ))
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        let coordinator = context.coordinator
        coordinator.bridge.reply = { [weak view, weak coordinator] message in
            guard let view, let documentId = coordinator?.documentId else { return }
            // callAsyncJavaScript passes data as an argument, never as executable source.
            view.callAsyncJavaScript(
                Self.replyScript, arguments: ["message": message, "documentId": documentId],
                in: nil, in: .page
            ) { _ in }
        }
        view.load(URLRequest(url: configuration.url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.bridge.payer = payer
        context.coordinator.bridge.callbacks = callbacks
    }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.bridge.active = false
        coordinator.bridge.reply = nil
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "crossmintOfframp")
    }

    static let replyScript = """
    if (window.__crossmintOfframpDocumentId === documentId) {
        window.onMessageFromRN(message);
    }
    """

    static let script = """
    (() => {
        const documentId = Array.from(crypto.getRandomValues(new Uint32Array(4))).join('-');
        window.__crossmintOfframpDocumentId = documentId;
        window.ReactNativeWebView = {
            postMessage: function(message) {
                window.webkit.messageHandlers.crossmintOfframp.postMessage(JSON.stringify({documentId, message}));
            }
        };
        window.onMessageFromRN = function(message) {
            window.dispatchEvent(new MessageEvent('message', {data: JSON.parse(message)}));
        };
    })();
    """

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        let bridge: EmbeddedOfframpBridge
        var documentId: String?

        init(bridge: EmbeddedOfframpBridge) {
            self.bridge = bridge
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let text = message.body as? String,
                  let data = text.data(using: .utf8),
                  let envelope = try? JSONDecoder().decode(PageMessage.self, from: data),
                  message.frameInfo.isMainFrame,
                  bridge.configuration.trusts(message.frameInfo.request.url) else { return }
            documentId = envelope.documentId
            let source = message.frameInfo.request.url
            let mainFrame = message.frameInfo.isMainFrame
            Task { await bridge.receive(envelope.message, source: source, mainFrame: mainFrame) }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            documentId = nil
            bridge.beginNavigation()
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            bridge.receiving = true
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            guard let frame = action.targetFrame else {
                decisionHandler(.cancel)
                return
            }
            let url = action.request.url
            if frame.isMainFrame {
                decisionHandler(bridge.configuration.trusts(url) ? .allow : .cancel)
            } else {
                // KYC providers embed HTTPS frames and create local media URLs.
                let allowed = ["https", "about", "blob"].contains(url?.scheme ?? "")
                decisionHandler(allowed ? .allow : .cancel)
            }
        }

        func webView(
            _ webView: WKWebView, decidePolicyFor response: WKNavigationResponse,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
        ) {
            if response.isForMainFrame, let http = response.response as? HTTPURLResponse, http.statusCode >= 400 {
                reportFailure("The offramp page returned HTTP \(http.statusCode)")
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error
        ) {
            reportFailure("The offramp page could not load")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            reportFailure("The offramp page could not load")
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            reportFailure("The offramp page stopped unexpectedly")
        }

        private struct PageMessage: Decodable {
            let documentId: String
            let message: String
        }

        private func reportFailure(_ message: String) {
            guard bridge.active else { return }
            bridge.beginNavigation()
            bridge.callbacks.onError(.init(reason: "invalid-configuration", retriable: false, message: message))
        }
    }
}
