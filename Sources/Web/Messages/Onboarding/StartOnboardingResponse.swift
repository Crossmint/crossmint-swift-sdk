public struct StartOnboardingResponse: WebViewMessage {
    public static let messageType = "response:start-onboarding"

    public struct ResponseData: Codable, Sendable {
        let status: ResponseStatus
        let signerStatus: SignerStatus?
        let error: String?
    }

    public let event: String
    let data: ResponseData

    public var status: ResponseStatus {
        data.status
    }

    public var errorMessage: String? {
        data.error
    }

    public var signerStatus: SignerStatus? {
        data.signerStatus
    }
}
