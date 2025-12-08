import Foundation
import WebKit
import Web

@MainActor
final class MockWebViewCommunicationProxy: NSObject, WebViewCommunicationProxy {
    public let name = "mockCrossmintMessageHandler"
    public weak var webView: WKWebView?
    public var onWebViewMessage: (any WebViewMessage) -> Void = { _ in }
    public var onUnknownMessage: (String, Data) -> Void = { _, _ in }

    var loadedURLs: [URL] = []
    var sentMessages: [any WebViewMessage] = []
    var resetCount = 0

    var shouldThrowOnLoad = false
    var loadError: WebViewError?

    var shouldThrowOnSend = false
    var sendError: WebViewError?

    var messageResponses: [String: any WebViewMessage] = [:]
    var waitResponses: [String: any WebViewMessage] = [:]
    var waitDelays: [String: TimeInterval] = [:]

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

        if let delay = waitDelays[typeName] {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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

    func configureResponseWithDelay<T: WebViewMessage>(for messageType: T.Type, response: T, delay: TimeInterval) {
        configureResponse(for: messageType, response: response)
        let typeName = String(describing: messageType)
        waitDelays[typeName] = delay
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
        waitDelays.removeValue(forKey: typeName)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Mock implementation - not needed for tests
    }
}
