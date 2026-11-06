//
//  SignerPageFixture.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 30/10/26.
//

import Foundation
import WebKit
@testable import Web

@MainActor
final class SignerPageFixture {
    static let SIGNER_URL = "crossmint-test://signer/"
    static let SIGNER_SECOND_PAGE_URL = "crossmint-test://signer/second"
    static let FOREIGN_URL = "crossmint-test://foreign/"

    private static let PAGES: [String: String] = [
        SIGNER_URL: page(posting: "from.signer"),
        SIGNER_SECOND_PAGE_URL: page(posting: "from.signer.second"),
        "crossmint-test://signer/frame": """
        <script>
        \(post("from.iframe"))
        parent.postMessage("posted", "*");
        </script>
        """,
        FOREIGN_URL: """
        <script>
        window.addEventListener("message", () => {
            \(post("from.foreign"))
            window.webkit.messageHandlers.probe.postMessage("foreign.done");
        });
        </script>
        <iframe src="crossmint-test://signer/frame"></iframe>
        """
    ]

    let proxy = DefaultWebViewCommunicationProxy()
    let webView: WKWebView
    let recorder = MessageRecorder()
    let navigation: NavigationPolicyRecorder
    private let schemeHandler = PageSchemeHandler(pages: PAGES)

    init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: "crossmint-test")

        let userContentController = WKUserContentController()
        userContentController.add(webViewCommunicationProxy: proxy)
        userContentController.add(recorder, name: "probe")
        configuration.userContentController = userContentController

        webView = WKWebView(frame: .zero, configuration: configuration)
        navigation = NavigationPolicyRecorder(proxy: proxy)
        webView.navigationDelegate = navigation
        proxy.webView = webView
        proxy.onUnknownMessage = { [recorder] type, _ in recorder.record(type) }
    }

    private static func page(posting type: String) -> String {
        "<script>\(post(type))</script>"
    }

    private static func post(_ type: String) -> String {
        "window.webkit.messageHandlers.crossmintMessageHandler.postMessage(JSON.stringify({ type: \"\(type)\" }));"
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
        await withTaskCancellationHandler {
            await withCheckedContinuation { waiters[type] = $0 }
        } onCancel: {
            Task { @MainActor in self.waiters.removeValue(forKey: type)?.resume() }
        }
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard let type = message.body as? String else { return }
        record(type)
    }
}

@MainActor
final class NavigationPolicyRecorder: NSObject, WKNavigationDelegate {
    private let proxy: DefaultWebViewCommunicationProxy
    private var policies: [String: WKNavigationActionPolicy] = [:]
    private var waiters: [String: CheckedContinuation<WKNavigationActionPolicy?, Never>] = [:]

    init(proxy: DefaultWebViewCommunicationProxy) {
        self.proxy = proxy
    }

    func policy(for url: String) async -> WKNavigationActionPolicy? {
        if let policy = policies[url] { return policy }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { waiters[url] = $0 }
        } onCancel: {
            Task { @MainActor in self.waiters.removeValue(forKey: url)?.resume(returning: nil) }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        let url = navigationAction.request.url?.absoluteString ?? ""
        proxy.webView(webView, decidePolicyFor: navigationAction) { [self] policy in
            policies[url] = policy
            waiters.removeValue(forKey: url)?.resume(returning: policy)
            decisionHandler(policy)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        proxy.webView(webView, didFinish: navigation)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        proxy.webView(webView, didFail: navigation, withError: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        proxy.webView(webView, didFailProvisionalNavigation: navigation, withError: error)
    }
}

final class PageSchemeHandler: NSObject, WKURLSchemeHandler {
    private let pages: [String: String]

    init(pages: [String: String]) {
        self.pages = pages
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let html = pages[url.absoluteString] else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let data = Data(html.utf8)
        urlSchemeTask.didReceive(URLResponse(
            url: url,
            mimeType: "text/html",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        ))
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
