import Foundation
import Logger
import UIKit
import WebKit

@MainActor
final class EmbeddedOfframpBridge: NSObject {
    var host: OfframpWebView
    var reply: ((String) -> Void)?
    var openExternally: (URL) -> Void = { UIApplication.shared.open($0) }
    // The page has one request of each kind in flight and no request IDs, so a reply goes to the request in `pending`.
    private var pending: [String: UUID] = [:]
    private var loadFailureReported = false

    init(host: OfframpWebView) {
        self.host = host
    }

    @discardableResult
    func receive(_ body: Any, frameURL: URL?, mainFrame: Bool) -> Task<Void, Never>? {
        guard mainFrame, isPage(frameURL), let data = (body as? String)?.data(using: .utf8),
              let event = try? JSONDecoder().decode(EventName.self, from: data).event else { return nil }
        let offramp = host.offramp
        switch event {
        case "ui:height.changed":
            deliver(data) { (size: Height) in self.host.height = size.height }
        case "offramp:ready":
            offramp.onReadyHandler?()
        case "offramp:status":
            deliver(data, to: offramp.onStatusChangeHandler)
        case "offramp:completed":
            deliver(data, to: offramp.onCompleteHandler)
        case "offramp:cancelled":
            offramp.onCancelHandler?()
        case "offramp:error":
            deliver(data, to: offramp.onErrorHandler)
        case "crypto:send-transaction":
            return payload(OfframpTransaction.self, data).flatMap { transaction in
                answer(event, key: "txId", empty: "The wallet returned no transaction id") {
                    try await self.host.offramp.payer.signAndSendTransaction(transaction)
                }
            }
        case "crypto:sign-message":
            return payload(OfframpMessage.self, data).flatMap { message in
                answer(event, key: "signature", empty: "The wallet returned no signature") {
                    let sign = self.host.offramp.payer.signMessage ?? Self.refuseMessage
                    return try await sign(message)
                }
            }
        default:
            break
        }
        return nil
    }

    func forgetPendingRequests() {
        pending = [:]
    }

    func navigationPolicy(for url: URL?, targetIsMainFrame: Bool?) -> WKNavigationActionPolicy {
        guard let url, !["javascript", "file"].contains(url.scheme?.lowercased()) else { return .cancel }
        switch targetIsMainFrame {
        case nil:
            if ["https", "http"].contains(url.scheme?.lowercased()) {
                openExternally(url)
            }
            return .cancel
        case false?:
            return .allow
        case true?:
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            let pageQuery = URLComponents(url: host.page, resolvingAgainstBaseURL: false)?.queryItems
            return isPage(url) && query == pageQuery ? .allow : .cancel
        }
    }

    func reportLoadFailure(status: Int) {
        reportLoadFailure("HTTP \(status)", retriable: status >= 500)
    }

    func reportLoadFailure(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        reportLoadFailure(nsError.localizedDescription, retriable: true)
    }

    private func reportLoadFailure(_ message: String, retriable: Bool) {
        guard !loadFailureReported else { return }
        loadFailureReported = true
        let error = OfframpError(
            reason: retriable ? .providerError : .invalidConfiguration, retriable: retriable, message: message
        )
        Logger.client.error(LogEvents.offrampLoadError, attributes: attributes([
            "reason": error.reason.rawValue, "message": message
        ]))
        host.offramp.onErrorHandler?(error)
    }

    private func isPage(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme == "https" && url.host == host.page.host && url.port == host.page.port
            && url.user == nil && url.password == nil && url.path == host.page.path
    }

    private func answer(
        _ event: String,
        key: String,
        empty: String,
        _ run: @escaping @MainActor () async throws -> String
    ) -> Task<Void, Never>? {
        guard pending[event] == nil else { return nil }
        let request = UUID()
        pending[event] = request
        return Task {
            let outcome: Reply
            do {
                let value = try await run()
                outcome = value.isEmpty ? .failed(error: empty, rejected: false) : .succeeded([key: value])
            } catch {
                outcome = .failed(error: error.localizedDescription, rejected: error is OfframpSignatureRejectedError)
            }
            guard pending[event] == request else { return }
            pending[event] = nil
            send(event, outcome)
        }
    }

    private func send(_ request: String, _ outcome: Reply) {
        let encoded: Data?
        let event: String
        switch outcome {
        case .succeeded(let data):
            event = "\(request):success"
            encoded = try? JSONEncoder().encode(Outgoing(event: event, data: data))
        case .failed(let error, let rejected):
            event = "\(request):failed"
            encoded = try? JSONEncoder().encode(Outgoing(event: event, data: Failure(error: error, rejected: rejected)))
        }
        Logger.client.info(LogEvents.offrampPayerReply, attributes: attributes(["event": event]))
        guard let encoded, let text = String(data: encoded, encoding: .utf8) else { return }
        reply?(text)
    }

    private func attributes(_ extra: [String: String]) -> [String: String] {
        extra.merging(["sessionId": host.offramp.credentials.sessionId]) { current, _ in current }
    }

    private func deliver<Payload: Decodable>(_ data: Data, to action: ((Payload) -> Void)?) {
        guard let action, let value = payload(Payload.self, data) else { return }
        action(value)
    }

    private func payload<Payload: Decodable>(_ type: Payload.Type, _ data: Data) -> Payload? {
        try? JSONDecoder().decode(Incoming<Payload>.self, from: data).data
    }

    private enum Reply {
        case succeeded([String: String])
        case failed(error: String, rejected: Bool)
    }

    private struct PayerFailure: LocalizedError {
        let errorDescription: String?
    }

    private static func refuseMessage(_ message: OfframpMessage) throws -> String {
        throw PayerFailure(errorDescription: "This payer cannot sign messages")
    }

    private struct EventName: Decodable { let event: String }
    private struct Incoming<Payload: Decodable>: Decodable { let data: Payload }
    private struct Outgoing<Payload: Encodable>: Encodable { let event: String; let data: Payload }
    private struct Height: Decodable { let height: CGFloat }
    private struct Failure: Encodable { let error: String; let rejected: Bool }
}

extension EmbeddedOfframpBridge: WKScriptMessageHandler {
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        receive(message.body, frameURL: message.frameInfo.request.url, mainFrame: message.frameInfo.isMainFrame)
    }
}

extension EmbeddedOfframpBridge: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(navigationPolicy(for: action.request.url, targetIsMainFrame: action.targetFrame?.isMainFrame))
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor response: WKNavigationResponse,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void
    ) {
        guard response.isForMainFrame, let status = (response.response as? HTTPURLResponse)?.statusCode, status >= 400
        else { return decisionHandler(.allow) }
        reportLoadFailure(status: status)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        forgetPendingRequests()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLoadFailure(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        Logger.client.error(LogEvents.offrampProcessTerminated, attributes: attributes([:]))
        loadFailureReported = false
        webView.load(URLRequest(url: host.page))
    }
}

extension EmbeddedOfframpBridge: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        decisionHandler(type == .camera ? .grant : .prompt)
    }
}
