public enum TransactionParams: Sendable {
    case evm(EVMTransactionParams)
    case solana(SolanaTransactionParams)
    case stellar(StellarTransactionParams)
}

public struct EVMTransactionParams: Sendable {
    public let to: String
    public let value: String?
    public let data: String?

    public init(to: String, value: String? = nil, data: String? = nil) {
        self.to = to
        self.value = value
        self.data = data
    }
}

public struct SolanaTransactionParams: Sendable {
    public let serializedTransaction: String

    public init(serializedTransaction: String) {
        self.serializedTransaction = serializedTransaction
    }
}

public struct StellarTransactionParams: Sendable {
    public let serializedTransaction: String

    public init(serializedTransaction: String) {
        self.serializedTransaction = serializedTransaction
    }
}
