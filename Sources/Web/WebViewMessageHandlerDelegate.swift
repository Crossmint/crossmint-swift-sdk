import Foundation

public protocol WebViewMessageHandlerDelegate: AnyObject {
    func handleWebViewMessage<T: WebViewMessage>(_ message: T)
    func handleUnknownMessage(_ messageType: String, data: Data)
}
