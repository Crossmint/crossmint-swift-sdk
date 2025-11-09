public struct TokenLinkOptions {
    public let isCompressed: Bool?
}

public struct BlockchainAddressLink {
    public let address: String
    public let chain: Chain
}

public struct BlockchainTransactionLink {
    public let txId: String
    public let chain: Chain
}

public struct BlockchainTokenLink {
    public let tokenLocator: String
    public let options: TokenLinkOptions?
}

public enum BlockchainExplorerLinkType {
    case address(BlockchainAddressLink)
    // TODO add token and transaction
}

public func getBlockchainExplorerURL(for link: BlockchainExplorerLinkType) -> String {
    // TODO implement
    fatalError("Not implemented")
}
