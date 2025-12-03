public struct CompleteOnboardingRequest: WebViewMessage {
    public static let messageType = "request:complete-onboarding"

    public struct AuthData: Codable, Equatable, Sendable {
        public let jwt: String
        public let apiKey: String
    }

    public struct RequestData: Codable, Equatable, Sendable {
        public struct Data: Codable, Equatable, Sendable {
            public struct OnboardingAuthenticationData: Codable, Equatable, Sendable {
                public let encryptedOtp: String
            }

            public let onboardingAuthentication: OnboardingAuthenticationData
        }
        public let authData: AuthData
        public let data: Data
    }

    public let event: String
    public let data: RequestData

    public init(jwt: String, apiKey: String, otp: String) {
        event = Self.messageType
        data = RequestData(
            authData: .init(jwt: jwt, apiKey: apiKey),
            data: .init(onboardingAuthentication: .init(encryptedOtp: otp))
        )
    }
}
