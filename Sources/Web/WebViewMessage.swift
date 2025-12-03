public protocol WebViewMessage: Equatable, Sendable, Codable {
    static var messageType: String { get }
}
