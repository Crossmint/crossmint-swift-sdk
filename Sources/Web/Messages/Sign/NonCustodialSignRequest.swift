public struct NonCustodialSignRequest: WebViewMessage {
    public static let messageType = "request:sign"

    public struct AuthData: Codable, Sendable {
        public let jwt: String
        public let apiKey: String
    }

    public struct SignData: Codable, Sendable {
        public let keyType: String
        public let bytes: String
        public let encoding: String
    }

    public struct RequestData: Codable, Sendable {
        public let authData: AuthData
        public let data: SignData
    }

    public let event: String
    public let data: RequestData

    public init(
        jwt: String,
        apiKey: String,
        messageBytes: String,
        keyType: String,
        encoding: String
    ) {
        event = Self.messageType
        data = RequestData(
            authData: AuthData(jwt: jwt, apiKey: apiKey),
            data: SignData(
                keyType: keyType,
                bytes: messageBytes,
                encoding: encoding
            )
        )
    }
}
