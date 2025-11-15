public struct SignRequestApi: Encodable {
    public enum Approval: Encodable {
        case keypair(signer: String, signature: String)
        case passkey(signer: String, signature: PasskeySignature, metadata: PasskeyMetadata)

        public struct PasskeySignature: Encodable {
            public let r: String
            public let s: String

            public init(r: String, s: String) {
                self.r = r
                self.s = s
            }
        }

        public struct PasskeyMetadata: Encodable {
            public let authenticatorData: String
            public let clientDataJSON: String
            public let challengeIndex: Int
            public let typeIndex: Int
            public let userVerificationRequired: Bool

            public init(
                authenticatorData: String,
                clientDataJSON: String,
                challengeIndex: Int = 23,
                typeIndex: Int = 1,
                userVerificationRequired: Bool = true
            ) {
                self.authenticatorData = authenticatorData
                self.clientDataJSON = clientDataJSON
                self.challengeIndex = challengeIndex
                self.typeIndex = typeIndex
                self.userVerificationRequired = userVerificationRequired
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .keypair(let signer, let signature):
                try container.encode(signer, forKey: .signer)
                try container.encode(signature, forKey: .signature)

            case .passkey(let signer, let signature, let metadata):
                try container.encode(signer, forKey: .signer)
                try container.encode(signature, forKey: .signature)
                try container.encode(metadata, forKey: .metadata)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case signer
            case signature
            case metadata
        }
    }

    public let approvals: [Approval]

    public init(approvals: [Approval]) {
        self.approvals = approvals
    }
}
