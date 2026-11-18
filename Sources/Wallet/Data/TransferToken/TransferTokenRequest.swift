import CrossmintCommonTypes

public struct TransferTokenRequest {
    public let chainType: ChainType
    public let tokenLocator: String
    public let recipient: String
    public let amount: String
    public let signer: String?
    public let idempotencyKey: String?
    public let approvingMembers: [String]?

    public init(
        chainType: ChainType,
        tokenLocator: String,
        recipient: String,
        amount: String,
        signer: String? = nil,
        idempotencyKey: String? = nil,
        approvingMembers: [String]? = nil
    ) {
        self.chainType = chainType
        self.tokenLocator = tokenLocator
        self.recipient = recipient
        self.amount = amount
        self.signer = signer
        self.idempotencyKey = idempotencyKey
        self.approvingMembers = approvingMembers
    }
}
