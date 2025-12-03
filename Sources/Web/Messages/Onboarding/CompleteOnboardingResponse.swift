public struct CompleteOnboardingResponse: WebViewMessage {
    public static let messageType = "response:complete-onboarding"

    public struct ResponseData: Codable, Equatable, Sendable {
        let status: ResponseStatus
        let signerStatus: SignerStatus?
        let publicKeys: PublicKeys?
    }

    public let event: String
    let data: ResponseData

    public var status: ResponseStatus {
        data.status
    }

    public var signerStatus: SignerStatus? {
        data.signerStatus
    }

    public var publicKeys: PublicKeys? {
        data.publicKeys
    }
}
