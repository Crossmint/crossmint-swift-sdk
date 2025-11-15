import Foundation

@MainActor
final class WebViewMessageRegistry {
    private static var messageTypes: [String: (Data) throws -> any WebViewMessage] = [:]

    static func register<T: WebViewMessage>(_ type: T.Type) {
        messageTypes[T.messageType] = { data in
            try JSONDecoder().decode(T.self, from: data)
        }
    }

    static func decode(messageType: String, data: Data) -> (any WebViewMessage)? {
        guard let decoder = messageTypes[messageType] else {
            return nil
        }

        return try? decoder(data)
    }

    static func registerDefaultTypes() {
        register(HandshakeRequest.self)
        register(HandshakeResponse.self)
        register(HandshakeComplete.self)

        register(GetStatusRequest.self)
        register(GetStatusResponse.self)

        register(StartOnboardingRequest.self)
        register(StartOnboardingResponse.self)

        register(CompleteOnboardingRequest.self)
        register(CompleteOnboardingResponse.self)

        register(NonCustodialSignRequest.self)
        register(NonCustodialSignResponse.self)
    }
}
