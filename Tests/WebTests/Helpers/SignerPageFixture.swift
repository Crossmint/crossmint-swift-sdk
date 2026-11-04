//
//  SignerPageFixture.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/11/26.
//

import Foundation
import Testing
import WebKit
@testable import Web

struct ProbeMessage: WebViewMessage {
    static let messageType = "probe"

    let type: String
}

@MainActor
final class SignerPageFixture {
    static let SIGNER_URL = "https://signers.crossmint.com/?deviceStorage=memory"
    static let SIGNER_SECOND_PAGE_URL = "https://signers.crossmint.com/second"
    static let SIGNER_FRAMES_URL = "https://signers.crossmint.com/frames"
    static let FOREIGN_URL = "https://evil.example/"
    static let INSECURE_SIGNER_URL = "http://signers.crossmint.com/"

    private static let PAGES: [String: String] = [
        SIGNER_URL: """
        <script>
        window.onMessageFromNative = function (message) { window.received = message; };
        \(post("signer.loaded"))
        </script>
        """,
        SIGNER_SECOND_PAGE_URL: "<script>\(post("signer.second"))</script>",
        SIGNER_FRAMES_URL: """
        <script>
        window.addEventListener("message", function () { \(post("signer.afterSubframe")) });
        </script>
        <iframe srcdoc="<script>\(post("subframe")) parent.postMessage('posted', '*');</script>"></iframe>
        <iframe src="data:text/html,<p>frame</p>"></iframe>
        """,
        FOREIGN_URL: """
        <script>
        window.onMessageFromNative = function (message) { window.received = message; };
        \(post("foreign"))
        window.webkit.messageHandlers.probe.postMessage('foreign.done');
        </script>
        """
    ]

    let proxy = DefaultWebViewCommunicationProxy()
    let webView: FakeNetworkWebView
    let navigations = NavigationRecorder()
    let messages = MessageRecorder()

    init(bridgeOrigin: SignerOrigin? = nil) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let userContentController = WKUserContentController()
        if let bridgeOrigin {
            userContentController.addUserScript(WKUserScript(
                source: CrossmintJavaScriptBridge.communicationScript(
                    bundleID: nil,
                    handlerName: proxy.name,
                    allowedOrigin: bridgeOrigin
                ),
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }
        userContentController.add(webViewCommunicationProxy: proxy)
        userContentController.add(messages, name: "probe")
        configuration.userContentController = userContentController

        webView = FakeNetworkWebView(pages: Self.PAGES, configuration: configuration)
        navigations.proxy = proxy
        webView.navigationDelegate = navigations
        proxy.webView = webView
        proxy.onUnknownMessage = { [messages] type, _ in messages.record(type) }
    }

    func url(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    func showWithoutProxy(_ string: String) async throws {
        let url = try url(string)
        navigations.proxy = nil
        webView.load(URLRequest(url: url))
        await navigations.wait { $0 == .finished(url) }
        navigations.proxy = proxy
    }

    func evaluate(_ script: String) async throws -> Any? {
        try await webView.evaluateJavaScript(script)
    }

    private static func post(_ type: String) -> String {
        "window.webkit.messageHandlers.crossmintMessageHandler.postMessage(JSON.stringify({ type: '\(type)' }));"
    }
}

@MainActor
final class FakeNetworkWebView: WKWebView {
    private let pages: [String: String]

    init(pages: [String: String], configuration: WKWebViewConfiguration) {
        self.pages = pages
        super.init(frame: .zero, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @discardableResult
    override func load(_ request: URLRequest) -> WKNavigation? {
        let html = request.url.flatMap { pages[$0.absoluteString] } ?? ""
        return loadHTMLString(html, baseURL: request.url)
    }
}

@MainActor
final class NavigationRecorder: NSObject, WKNavigationDelegate {
    enum Event: Equatable {
        case decided(url: URL?, isMainFrame: Bool, policy: WKNavigationActionPolicy)
        case finished(URL?)
    }

    weak var proxy: DefaultWebViewCommunicationProxy?
    private(set) var events: [Event] = []
    private var waiters: [(matches: (Event) -> Bool, continuation: CheckedContinuation<Void, Never>)] = []

    func wait(for matches: @escaping (Event) -> Bool) async {
        guard !events.contains(where: matches) else { return }
        await withCheckedContinuation { waiters.append((matches, $0)) }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        let url = navigationAction.request.url
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        guard let proxy else {
            record(.decided(url: url, isMainFrame: isMainFrame, policy: .allow))
            decisionHandler(.allow)
            return
        }

        proxy.webView(webView, decidePolicyFor: navigationAction) { [weak self] policy in
            self?.record(.decided(url: url, isMainFrame: isMainFrame, policy: policy))
            decisionHandler(policy)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        proxy?.webView(webView, didFinish: navigation)
        record(.finished(webView.url))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        proxy?.webView(webView, didFail: navigation, withError: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        proxy?.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }

    private func record(_ event: Event) {
        events.append(event)
        let ready = waiters.filter { $0.matches(event) }
        waiters.removeAll { $0.matches(event) }
        ready.forEach { $0.continuation.resume() }
    }
}

@MainActor
final class MessageRecorder: NSObject, WKScriptMessageHandler {
    private(set) var types: [String] = []
    private var waiters: [String: CheckedContinuation<Void, Never>] = [:]

    func record(_ type: String) {
        types.append(type)
        waiters.removeValue(forKey: type)?.resume()
    }

    func wait(for type: String) async {
        guard !types.contains(type) else { return }
        await withCheckedContinuation { waiters[type] = $0 }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let type = message.body as? String else { return }
        record(type)
    }
}
