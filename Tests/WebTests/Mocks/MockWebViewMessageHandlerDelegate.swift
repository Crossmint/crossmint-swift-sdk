import Foundation
@testable import Web

final class MockWebViewMessageHandlerDelegate: WebViewMessageHandlerDelegate {
    var receivedMessages: [any WebViewMessage] = []
    var receivedUnknownMessages: [(type: String, data: Data)] = []

    func handleWebViewMessage<T: WebViewMessage>(_ message: T) {
        receivedMessages.append(message)
    }

    func handleUnknownMessage(_ messageType: String, data: Data) {
        receivedUnknownMessages.append((type: messageType, data: data))
    }
}
