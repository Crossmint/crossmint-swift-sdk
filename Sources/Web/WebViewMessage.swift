public protocol WebViewMessage: Sendable, Codable {
    static var messageType: String { get }
}
