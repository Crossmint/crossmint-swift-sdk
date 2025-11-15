public struct NonCustodialSignResponse: WebViewMessage {
    public static let messageType = "response:sign"

    public struct ResponseData: Codable, Sendable {
        public let status: ResponseStatus
        public let signature: PublicKey?
        public let publicKey: PublicKey?
        public let error: String?
    }

    public let event: String
    public let data: ResponseData

    public var status: ResponseStatus {
        data.status
    }

    public var signature: PublicKey? {
        data.signature
    }

    public var signatureBytes: String? {
        data.signature?.bytes
    }

    public var publicKey: PublicKey? {
        data.publicKey
    }

    public var errorMessage: String? {
        data.error
    }
}
