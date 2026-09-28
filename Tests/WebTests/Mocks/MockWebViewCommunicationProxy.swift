import Foundation
import WebKit
import Web

@MainActor
final class MockWebViewCommunicationProxy: NSObject, WebViewCommunicationProxy {
    public let name = "mockCrossmintMessageHandler"
    public weak var webView: WKWebView?
    public var onWebViewMessage: (any WebViewMessage) -> Void = { _ in }
    public var onUnknownMessage: (String, Data) -> Void = { _, _ in }
    public var onWebContentProcessTerminated: @MainActor () -> Void = {}

    var loadedURLs: [URL] = []
    var sentMessages: [any WebViewMessage] = []
    var resetCount = 0
    var completeOnboardingRequestCount = 0

    var shouldThrowOnLoad = false
    var loadError: WebViewError?

    var shouldThrowOnSend = false
    var sendError: WebViewError?

    var messageResponses: [String: any WebViewMessage] = [:]
    var waitResponses: [String: any WebViewMessage] = [:]
    private var heldResponseTypes: Set<String> = []
    private var heldResponseWaiters: [String: [CheckedContinuation<Void, Never>]] = [:]
    private var responseAwaitedObservers: [String: [CheckedContinuation<Void, Never>]] = [:]

    func loadURL(_ url: URL) async throws {
        if shouldThrowOnLoad {
            throw loadError ?? WebViewError.webViewNotAvailable
        }
        loadedURLs.append(url)
    }

    func resetLoadedContent() {
        resetCount += 1
        loadedURLs.removeAll()
        sentMessages.removeAll()
    }

    func sendMessage<T: WebViewMessage>(_ message: T) async throws(WebViewError) -> Any? {
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

    func waitForMessage<T: WebViewMessage>(
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

        throw WebViewError.timeout
    }

    func configureResponse<T: WebViewMessage>(for messageType: T.Type, response: T) {
        let typeName = String(describing: messageType)
        waitResponses[typeName] = response
    }

    func holdResponse<T: WebViewMessage>(for messageType: T.Type, response: T) {
        configureResponse(for: messageType, response: response)
        heldResponseTypes.insert(String(describing: messageType))
    }

    func waitUntilResponseIsAwaited<T: WebViewMessage>(for messageType: T.Type) async {
        let typeName = String(describing: messageType)
        guard heldResponseWaiters[typeName, default: []].isEmpty else { return }
        await withCheckedContinuation { continuation in
            responseAwaitedObservers[typeName, default: []].append(continuation)
        }
    }

    func releaseResponse<T: WebViewMessage>(for messageType: T.Type) {
        let typeName = String(describing: messageType)
        heldResponseTypes.remove(typeName)
        heldResponseWaiters.removeValue(forKey: typeName)?.forEach { $0.resume() }
    }

    func configureSendResponse<T: WebViewMessage>(for messageType: T.Type, response: any WebViewMessage) {
        let typeName = String(describing: messageType)
        messageResponses[typeName] = response
    }

    func lastSentMessage<T: WebViewMessage>(ofType type: T.Type) -> T? {
        return sentMessages.last { $0 is T } as? T
    }

    func sentMessages<T: WebViewMessage>(ofType type: T.Type) -> [T] {
        return sentMessages.compactMap { $0 as? T }
    }

    func clearResponse<T: WebViewMessage>(for messageType: T.Type) {
        let typeName = String(describing: messageType)
        waitResponses.removeValue(forKey: typeName)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(
        _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
    ) {
        // Mock implementation - not needed for tests
    }
}
