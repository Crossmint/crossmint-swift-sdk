public struct GetStatusRequest: WebViewMessage {
    public static let messageType = "request:get-status"

    public struct AuthData: Codable, Sendable {
        public let jwt: String
        public let apiKey: String
    }

    public struct RequestData: Codable, Sendable {
        public let authData: AuthData
    }

    public let event: String
    public let data: RequestData

    public init(jwt: String, apiKey: String) {
        event = Self.messageType
        data = RequestData(authData: AuthData(jwt: jwt, apiKey: apiKey))
    }
}
