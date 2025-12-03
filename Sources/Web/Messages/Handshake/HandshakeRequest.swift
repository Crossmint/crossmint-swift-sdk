public struct HandshakeRequest: WebViewMessage {
    public static let messageType = "handshakeRequest"

    struct Data: Codable, Equatable, Sendable {
        let requestVerificationId: String
    }
    let event: String
    let data: Data

    public init(requestVerificationId: String) {
        event = Self.messageType
        data = Data(requestVerificationId: requestVerificationId)
    }
}
