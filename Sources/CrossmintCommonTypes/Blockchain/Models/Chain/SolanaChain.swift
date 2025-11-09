public enum SolanaChain: SpecificChain, Equatable {
    public var chain: Chain {
        .solana
    }

    public var chainType: ChainType {
        .solana
    }

    public var name: String {
        "solana"
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        true
    }

    public init?(_ from: String) {
        if from.uppercased() != "SOLANA" {
            return nil
        }
        self = .solana
    }

    case solana
}
