import Utils

public enum Address: BlockchainAddress, CustomStringConvertible {
    case solana(SolanaAddress)
    case evm(EVMAddress)

    public init(address: String) throws(BlockchainAddressError) {
        if let solanaAddress = try? SolanaAddress(address: address) {
            self = .solana(solanaAddress)
        } else if let evmAddress = try? EVMAddress(address: address) {
            self = .evm(evmAddress)
        } else {
            throw BlockchainAddressError.chainNotSupported(
                "Unsupported blockchain address format: \(address)")
        }
    }

    public static func validateAddressAndReturnAddress(_ address: String, chain: Chain? = nil)
        -> Address? {
        if let chain = chain {
            switch chain.chainType {
            case .solana:
                return try? .solana(SolanaAddress(address: address))
            case .evm:
                return try? .evm(EVMAddress(address: address))
            case .unknown:
                return nil
            }
        }

        // No chain provided, try all supported chains
        do {
            // Try to create an AnyBlockChainPublicKeyAddress which will validate for all supported chains
            return try Address(address: address)
        } catch {
            return nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .solana(let solanaAddress):
            try container.encode(solanaAddress)
        case .evm(let evmAddress):
            try container.encode(evmAddress)
        }
    }

    public var hiddenPublicKeyAddress: String {
        return cutMiddleAndAddEllipsis(self.description, beginLength: 6, endLength: 6)
    }

    public var description: String {
        switch self {
        case .solana(let solanaAddress):
            return solanaAddress.address
        case .evm(let evmAddress):
            return evmAddress.address
        }
    }
}
