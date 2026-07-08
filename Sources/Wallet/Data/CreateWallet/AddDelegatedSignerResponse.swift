public struct RegistrationApprovals: Decodable {
    public let pending: [ApprovalEntry]
}

/// Marker for an on-chain (transaction) registration entry. Its presence — not its
/// contents — determines whether approval goes through the transaction flow instead
/// of the signature flow.
public struct ChainRegistrationOnChain: Decodable {}

public struct ChainRegistrationEntry: Decodable {
    public let id: String?
    public let status: String?
    public let approvals: RegistrationApprovals?
    public let onChain: ChainRegistrationOnChain?

    init(id: String?, status: String?, approvals: RegistrationApprovals?, onChain: ChainRegistrationOnChain? = nil) {
        self.id = id
        self.status = status
        self.approvals = approvals
        self.onChain = onChain
    }

    var awaitsApproval: Bool {
        status == "pending" || status == "awaiting-approval"
    }
}

/// Pending transaction returned when registering a signer on Solana/Stellar wallets,
/// which approve registrations through a regular transaction instead of the per-chain
/// entries EVM returns under `chains`.
public struct RegistrationTransaction: Decodable {
    public let id: String
}

public struct AddDelegatedSignerResponse: Decodable {
    public let chains: [String: ChainRegistrationEntry]?
    public let transaction: RegistrationTransaction?
}
