import Utils

public struct GetStatusResponse: WebViewMessage {
    public static let messageType = "response:get-status"

    public enum ResponseData: Codable, Equatable, Sendable {
        case basic(BasicResponseData)
        case withPublicKeys(PublicKeysResponseData)

        public struct BasicResponseData: Codable, Equatable, Sendable {
            let status: ResponseStatus
            let signerStatus: SignerStatus?
            let error: String?
        }

        public struct PublicKeysResponseData: Codable, Equatable, Sendable {
            let status: ResponseStatus
            let signerStatus: SignerStatus
            let publicKeys: PublicKeys
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let status = try container.decode(ResponseStatus.self, forKey: .status)

            if container.contains(.publicKeys) {
                let signerStatus = try container.decode(SignerStatus.self, forKey: .signerStatus)
                let publicKeys = try container.decode(PublicKeys.self, forKey: .publicKeys)
                self = .withPublicKeys(PublicKeysResponseData(
                    status: status,
                    signerStatus: signerStatus,
                    publicKeys: publicKeys
                ))
            } else {
                let signerStatus = try container.decodeIfPresent(SignerStatus.self, forKey: .signerStatus)
                let error = try container.decodeIfPresent(String.self, forKey: .error)
                self = .basic(BasicResponseData(
                    status: status,
                    signerStatus: signerStatus,
                    error: error
                ))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)

            switch self {
            case .basic(let data):
                try container.encode(data.status, forKey: .status)
                try container.encodeIfPresent(data.signerStatus, forKey: .signerStatus)
                try container.encodeIfPresent(data.error, forKey: .error)
            case .withPublicKeys(let data):
                try container.encode(data.status, forKey: .status)
                try container.encode(data.signerStatus, forKey: .signerStatus)
                try container.encode(data.publicKeys, forKey: .publicKeys)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case status
            case signerStatus
            case error
            case publicKeys
        }
    }

    public let event: String
    public let data: ResponseData

    public var status: ResponseStatus {
        switch data {
        case .basic(let basicData):
            return basicData.status
        case .withPublicKeys(let publicKeysData):
            return publicKeysData.status
        }
    }

    public var errorMessage: String? {
        switch data {
        case .basic(let basicData):
            return basicData.error
        case .withPublicKeys:
            return nil
        }
    }

    public var signerStatus: SignerStatus? {
        switch data {
        case .basic(let basicData):
            return basicData.signerStatus
        case .withPublicKeys(let publicKeysData):
            return publicKeysData.signerStatus
        }
    }

    public var publicKeys: PublicKeys? {
        switch data {
        case .basic:
            return nil
        case .withPublicKeys(let publicKeysData):
            return publicKeysData.publicKeys
        }
    }
}
