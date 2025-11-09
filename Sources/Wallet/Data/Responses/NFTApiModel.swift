import CrossmintCommonTypes
import Foundation

struct NFTApiModel: Decodable {
    struct Locator: Sendable {
        let chain: Chain
        let contractAddress: String
        let tokenId: String
    }

    struct Metadata: Codable {
        public let collection: [String: String]
        public let animationUrl: URL?
        public let name: String
        public let description: String
        public let attributes: [String]
        public let image: URL

        enum CodingKeys: String, CodingKey {
            case collection
            case animationUrl = "animation_url"
            case name
            case description
            case attributes
            case image
        }
    }

    enum CodingKeys: CodingKey {
        case metadata
        case chain
        case tokenStandard
        case contractAddress
        case tokenId
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.metadata = try container.decode(NFTApiModel.Metadata.self, forKey: .metadata)
        self.chain = Chain(try container.decode(String.self, forKey: .chain))
        self.tokenStandard = try container.decode(String.self, forKey: .tokenStandard)
        self.contractAddress = try container.decode(String.self, forKey: .contractAddress)
        self.tokenId = try container.decode(String.self, forKey: .tokenId)
    }

    let metadata: Metadata
    let chain: Chain
    let tokenStandard: String
    let contractAddress: String
    let tokenId: String
}
