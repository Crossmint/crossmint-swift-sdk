public enum UnknownChain: SpecificChain {
    public var chain: Chain {
        .unknown(name: name)
    }

    public var chainType: ChainType {
        .unknown
    }

    public var name: String {
        switch self {
        case .unknown(let name, _):
            name
        }
    }

    public func isValid(isProductionEnvironment: Bool) -> Bool {
        true
    }

    public init?(_ from: String) {
        self = .unknown(name: from, isTest: true)
    }

    case unknown(name: String, isTest: Bool)
}
