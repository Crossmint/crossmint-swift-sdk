public enum UnknownChain: SpecificChain {
    public var chain: Chain {
        .unknown(name: name)
    }

    public var chainType: ChainType {
        .unknown
    }

    public var name: String {
        switch self {
        case .unknown(let name):
            name
        }
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        false
    }

    public init?(_ from: String) {
        self = .unknown(name: from)
    }

    case unknown(name: String)
}
