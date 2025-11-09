import CrossmintCommonTypes

public enum ChainAndAddress: CustomStringConvertible, Equatable, Hashable, Encodable {
    case evm(EVMChain, EVMAddress)
    case solana(SolanaAddress)

    public var description: String {
        "\(chain.name):\(blockchainAddress.description)"
    }

    public var chain: Chain {
        switch self {
        case .evm(let evmChain, _):
            evmChain.chain
        case .solana:
            Chain.solana
        }
    }

    public var blockchainAddress: any BlockchainAddress {
        switch self {
        case .evm(_, let address):
            address
        case .solana(let address):
            address
        }
    }
}
