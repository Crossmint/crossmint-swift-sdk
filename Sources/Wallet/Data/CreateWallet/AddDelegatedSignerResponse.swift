public struct RegistrationApprovals: Decodable {
    public let pending: [ApprovalEntry]
}

public struct ChainRegistrationEntry: Decodable {
    public let id: String?
    public let status: String?
    public let approvals: RegistrationApprovals?
}

/// Pending transaction returned when registering a signer on Solana/Stellar wallets,
/// which approve registrations through a regular transaction instead of the per-chain
/// entries EVM returns under `chains`.
public struct RegistrationTransaction: Decodable {
    public let id: String
    public let status: String?

    init(id: String, status: String? = nil) {
        self.id = id
        self.status = status
    }
}

public struct AddDelegatedSignerResponse: Decodable {
    public let chains: [String: ChainRegistrationEntry]?
    public let transaction: RegistrationTransaction?
}
