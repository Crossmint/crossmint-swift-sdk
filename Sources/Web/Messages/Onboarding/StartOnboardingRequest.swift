public struct StartOnboardingRequest: WebViewMessage {
    public static let messageType = "request:start-onboarding"

    public struct AuthData: Codable, Sendable {
        public let jwt: String
        public let apiKey: String
    }

    public struct RequestData: Codable, Sendable {
        public struct Data: Codable, Sendable {
            public let authId: String
        }
        public let authData: AuthData
        public let data: Data
    }

    public let event: String
    public let data: RequestData

    public init(jwt: String, apiKey: String, authId: String) {
        event = Self.messageType
        data = RequestData(
            authData: AuthData(jwt: jwt, apiKey: apiKey),
            data: RequestData.Data(authId: authId)
        )
    }
}
