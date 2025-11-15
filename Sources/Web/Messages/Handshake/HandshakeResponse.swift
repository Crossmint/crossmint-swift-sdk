public struct HandshakeResponse: WebViewMessage {
    public static let messageType = "handshakeResponse"

    public struct Data: Codable, Sendable {
        public let requestVerificationId: String
    }
    public let event: String
    public let data: Data

    init(requestVerificationId: String) {
        event = Self.messageType
        data = Data(requestVerificationId: requestVerificationId)
    }
}
