public struct HandshakeComplete: WebViewMessage {
    public static let messageType = "handshakeComplete"

    public struct Data: Codable, Sendable {
        public let requestVerificationId: String
    }
    public let event: String
    public let data: Data

    public init(requestVerificationId: String) {
        event = Self.messageType
        data = Data(requestVerificationId: requestVerificationId)
    }
}
