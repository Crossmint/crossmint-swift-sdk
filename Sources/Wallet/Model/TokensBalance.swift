import CrossmintCommonTypes

public struct Balance: Equatable, Sendable {
    public let nativeToken: TokenBalance
    public let usdc: TokenBalance
    public let tokens: [TokenBalance]

    public init(nativeToken: TokenBalance, usdc: TokenBalance, tokens: [TokenBalance]) {
        self.nativeToken = nativeToken
        self.usdc = usdc
        self.tokens = tokens
    }
}

public struct TokenAmount: Equatable, Sendable {
    public let amount: String
    public let rawAmount: String

    public init(amount: String, rawAmount: String) {
        self.amount = amount
        self.rawAmount = rawAmount
    }
}

public enum TokenAccountType: Equatable, Sendable {
    case wallet
    case card(provider: String)
    /// An account type that this version of the SDK does not know.
    /// The value is the type name that the API sent.
    case unknown(String)
}

public struct TokenAccountBalance: Equatable, Sendable {
    public let type: TokenAccountType
    public let amount: String
    public let rawAmount: String
    public let available: TokenAmount
    public let locked: TokenAmount

    public init(
        type: TokenAccountType,
        amount: String,
        rawAmount: String,
        available: TokenAmount,
        locked: TokenAmount
    ) {
        self.type = type
        self.amount = amount
        self.rawAmount = rawAmount
        self.available = available
        self.locked = locked
    }
}

public struct TokenBalance: Equatable, Sendable {
    public enum Symbol: Equatable, Sendable {
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
    /// The part of the balance that the wallet can spend now, on the wallet's own chain.
    /// The value is nil when the balance API does not give it.
    public let available: TokenAmount?
    /// The part of the balance that the wallet cannot spend yet, such as a card charge that is pending.
    /// The value is nil when the balance API does not give it.
    public let locked: TokenAmount?
    /// The balance of this token in each account that holds it, such as the wallet and a card.
    /// The value is nil when the balance API does not give it.
    public let accounts: [TokenAccountBalance]?

    public init(
        symbol: Symbol,
        name: String,
        amount: String,
        contractAddress: String? = nil,
        decimals: Int? = nil,
        rawAmount: String? = nil,
        available: TokenAmount? = nil,
        locked: TokenAmount? = nil,
        accounts: [TokenAccountBalance]? = nil
    ) {
        self.symbol = symbol
        self.name = name
        self.amount = amount
        self.contractAddress = contractAddress
        self.decimals = decimals
        self.rawAmount = rawAmount
        self.available = available
        self.locked = locked
        self.accounts = accounts
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
