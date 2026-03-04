public struct RegistrationApprovals: Decodable {
    public let pending: [ApprovalEntry]
}

public struct ChainRegistrationEntry: Decodable {
    public let id: String?
    public let status: String?
    public let approvals: RegistrationApprovals?
}

public struct AddDelegatedSignerResponse: Decodable {
    public let chains: [String: ChainRegistrationEntry]?
}
