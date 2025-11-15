import CrossmintCommonTypes
import Foundation

public struct NFT: Sendable, Hashable, Equatable, Identifiable {
    public var id: String {
        tokenId
    }

    public struct Locator: Sendable, Hashable, Equatable {
        let chain: Chain
        let contractAddress: String
        let tokenId: String

        public var value: String {
            "\(chain.name):\(contractAddress):\(tokenId)"
        }

        static func map(_ locator: NFTApiModel.Locator) -> Locator {
            Locator(
                chain: locator.chain,
                contractAddress: locator.contractAddress,
                tokenId: locator.tokenId
            )
        }
    }

    public struct Metadata: Codable, Sendable, Hashable, Equatable {
        public let collection: [String: String]
        public let animationUrl: URL?
        public let name: String
        public let description: String
        public let attributes: [String]
        public let image: URL

        static func map(_ metadata: NFTApiModel.Metadata) -> Metadata {
            Metadata(
                collection: metadata.collection,
                animationUrl: metadata.animationUrl,
                name: metadata.name,
                description: metadata.description,
                attributes: metadata.attributes,
                image: metadata.image
            )
        }
    }

    public let metadata: Metadata
    public let chain: Chain
    public let tokenStandard: String
    public let contractAddress: String
    public let tokenId: String
    public var locator: Locator {
        Locator(chain: chain, contractAddress: contractAddress, tokenId: tokenId)
    }

    static func map(_ nft: NFTApiModel) -> NFT {
        NFT(
            metadata: .map(nft.metadata),
            chain: nft.chain,
            tokenStandard: nft.tokenStandard,
            contractAddress: nft.contractAddress,
            tokenId: nft.tokenId
        )
    }
}
