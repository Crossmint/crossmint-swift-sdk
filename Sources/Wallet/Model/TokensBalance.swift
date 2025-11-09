import CrossmintCommonTypes

public struct Balance: Equatable {
    public let nativeToken: TokenBalance
    public let usdc: TokenBalance
    public let tokens: [TokenBalance]

    public init(nativeToken: TokenBalance, usdc: TokenBalance, tokens: [TokenBalance]) {
        self.nativeToken = nativeToken
        self.usdc = usdc
        self.tokens = tokens
    }
}

public struct TokenBalance: Equatable {
    public enum Symbol: Equatable {
        case sol
        case eth
        case usdc
        case symbol(String)

        public var value: String {
            switch self {
            case .sol: "sol"
            case .eth: "eth"
            case .usdc: "usdc"
            case .symbol(let symbol): symbol
            }
        }
    }

    public let symbol: Symbol
    public let name: String
    public let amount: String
    public let contractAddress: String?
    public let decimals: Int?
    public let rawAmount: String?

    public init(
        symbol: Symbol,
        name: String,
        amount: String,
        contractAddress: String? = nil,
        decimals: Int? = nil,
        rawAmount: String? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.amount = amount
        self.contractAddress = contractAddress
        self.decimals = decimals
        self.rawAmount = rawAmount
    }

    public var token: CryptoCurrency {
        switch symbol {
        case .sol:
            return .sol
        case .eth:
            return .eth
        case .usdc:
            return .usdc
        case .symbol(let value):
            return .unknown(value)
        }
    }
}
