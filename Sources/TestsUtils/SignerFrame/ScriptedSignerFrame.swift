import Foundation
import WebKit
import Web

@MainActor
package final class ScriptedSignerFrame: NSObject, WebViewCommunicationProxy {
    public let name = "mockCrossmintMessageHandler"
    public weak var webView: WKWebView?
    public var onWebViewMessage: (any WebViewMessage) -> Void = { _ in }
    public var onUnknownMessage: (String, Data) -> Void = { _, _ in }
    public var onWebContentProcessTerminated: @MainActor () -> Void = {}

    package var loadedURLs: [URL] = []
    package var sentMessages: [any WebViewMessage] = []
    package var resetCount = 0
    package var completeOnboardingRequestCount = 0

    package var shouldThrowOnLoad = false
    package var loadError: WebViewError?

    package var shouldThrowOnSend = false
    package var sendError: WebViewError?

    package var messageResponses: [String: any WebViewMessage] = [:]
    package var waitResponses: [String: any WebViewMessage] = [:]
    package var signResponder: ((NonCustodialSignRequest) -> NonCustodialSignResponse)?
    private var heldResponseTypes: Set<String> = []
    private var heldResponseWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var responseAwaitedObservers: [String: [CheckedContinuation<Void, Never>]] = [:]

    public func loadURL(_ url: URL) async throws {
        if shouldThrowOnLoad {
            throw loadError ?? WebViewError.webViewNotAvailable
        }
        loadedURLs.append(url)
    }

    public func resetLoadedContent() {
        resetCount += 1
        loadedURLs.removeAll()
        sentMessages.removeAll()
    }

    public func sendMessage<T: WebViewMessage>(_ message: T) async throws(WebViewError) -> Any? {
        if shouldThrowOnSend {
            throw sendError ?? .javascriptEvaluationError
        }
        if message is CompleteOnboardingRequest {
            completeOnboardingRequestCount += 1
        }
        sentMessages.append(message)

        let messageType = String(describing: type(of: message))
        if let response = messageResponses[messageType] {
            return response
        }
        return nil
    }

    public func waitForMessage<T: WebViewMessage>(
        ofType type: T.Type,
        matching predicate: @escaping @Sendable (T) -> Bool = { _ in true },
        timeout: TimeInterval
    ) async throws -> T {
        let typeName = String(describing: type)

        if heldResponseTypes.contains(typeName) {
            await withCheckedContinuation { continuation in
                heldResponseWaiters[typeName, default: []].append(continuation)
                responseAwaitedObservers.removeValue(forKey: typeName)?.forEach { $0.resume() }
            }
        }

        if let response = waitResponses[typeName] as? T {
            if predicate(response) {
                return response
            }
        }
        if type == NonCustodialSignResponse.self, let signResponder,
           let request = lastSentMessage(ofType: NonCustodialSignRequest.self),
           let response = signResponder(request) as? T, predicate(response) {
            return response
        }

        throw WebViewError.timeout
    }

    package func configureResponse<T: WebViewMessage>(for messageType: T.Type, response: T) {
        let typeName = String(describing: messageType)
        waitResponses[typeName] = response
    }

    package func holdResponse<T: WebViewMessage>(for messageType: T.Type, response: T) {
        configureResponse(for: messageType, response: response)
        heldResponseTypes.insert(String(describing: messageType))
    }

    package func waitUntilResponseIsAwaited<T: WebViewMessage>(for messageType: T.Type) async {
        let typeName = String(describing: messageType)
        guard heldResponseWaiters[typeName, default: []].isEmpty else { return }
        await withCheckedContinuation { continuation in
            responseAwaitedObservers[typeName, default: []].append(continuation)
        }
    }

    package func releaseResponse<T: WebViewMessage>(for messageType: T.Type) {
        let typeName = String(describing: messageType)
        heldResponseTypes.remove(typeName)
        heldResponseWaiters.removeValue(forKey: typeName)?.forEach { $0.resume() }
    }

    package func configureSendResponse<T: WebViewMessage>(for messageType: T.Type, response: any WebViewMessage) {
        let typeName = String(describing: messageType)
        messageResponses[typeName] = response
    }

    package func lastSentMessage<T: WebViewMessage>(ofType type: T.Type) -> T? {
        return sentMessages.last { $0 is T } as? T
    }

    package func sentMessages<T: WebViewMessage>(ofType type: T.Type) -> [T] {
        return sentMessages.compactMap { $0 as? T }
    }

    package func clearResponse<T: WebViewMessage>(for messageType: T.Type) {
        let typeName = String(describing: messageType)
        waitResponses.removeValue(forKey: typeName)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
    }
}
