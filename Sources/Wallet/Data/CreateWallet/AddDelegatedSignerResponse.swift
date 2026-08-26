import CrossmintCommonTypes

public struct RegistrationApprovals: Decodable {
    public let pending: [ApprovalEntry]
}

/// Marker for an on-chain (transaction) registration entry. When present, approval
/// goes through the transaction flow instead of the signature flow.
public struct ChainRegistrationOnChain: Decodable {}

public struct ChainRegistrationEntry: Decodable {
    public let id: String?
    public let status: SignerStatus
    public let approvals: RegistrationApprovals?
    public let onChain: ChainRegistrationOnChain?

    init(
        id: String?,
        status: SignerStatus,
        approvals: RegistrationApprovals?,
        onChain: ChainRegistrationOnChain? = nil
    ) {
        self.id = id
        self.status = status
        self.approvals = approvals
        self.onChain = onChain
    }

    private enum CodingKeys: String, CodingKey {
        case id, status, approvals, onChain
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        status = try container.decodeIfPresent(SignerStatus.self, forKey: .status) ?? .unknown
        approvals = try container.decodeIfPresent(RegistrationApprovals.self, forKey: .approvals)
        onChain = try container.decodeIfPresent(ChainRegistrationOnChain.self, forKey: .onChain)
    }

    var awaitsApproval: Bool {
        switch status {
        case .pending, .awaitingApproval:
            return true
        case .active, .failed, .unknown:
            return false
        }
    }
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

extension AddDelegatedSignerResponse {
    /// Resolves the signer's registration status the way each chain family reports it:
    /// EVM approval state lives in the per-chain entries; Solana and Stellar approve through
    /// a transaction. An empty `chains` map means the signer was created together with the
    /// wallet and needed no approval.
    ///
    /// Returns `nil` on EVM when the signer has no registration entry for `chainName`,
    /// which means it is not registered on that chain.
    func registrationStatus(chainType: ChainType, chainName: String) -> SignerStatus? {
        if chainType == .solana || chainType == .stellar {
            return SignerStatus.from(transaction?.status ?? "success")
        }
        guard let chains, !chains.isEmpty else {
            return .active
        }
        return chains[chainName]?.status
    }
}
