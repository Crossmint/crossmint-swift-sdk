import CrossmintCommonTypes

public protocol EmailRecipient: Codable, Sendable {
    var email: String { get set }
}

public protocol WalletAddressRecipient: Codable, Sendable {
    var walletAddress: Address { get set }
}

public struct EmailWithOptionalPhysicalAddressRecipient: EmailRecipient {
    public var email: String
    public var physicalAddress: PhysicalAddress?

    public init(email: String, physicalAddress: PhysicalAddress? = nil) {
        self.email = email
        self.physicalAddress = physicalAddress
    }
}

public struct WalletAddressWithOptionalPhysicalAddressRecipient: WalletAddressRecipient {
    public var walletAddress: Address
    public var physicalAddress: PhysicalAddress?

    public init(walletAddress: Address, physicalAddress: PhysicalAddress?) {
        self.walletAddress = walletAddress
        self.physicalAddress = physicalAddress
    }
}

public enum RecipientInput: Codable, Sendable {
    case emailWithOptionalPhysicalAddress(EmailWithOptionalPhysicalAddressRecipient)
    case walletAddressWithOptionalPhysicalAddress(WalletAddressWithOptionalPhysicalAddressRecipient)

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .emailWithOptionalPhysicalAddress(let recipient): try container.encode(recipient)
        case .walletAddressWithOptionalPhysicalAddress(let recipient):
            try container.encode(recipient)
        }
    }
}
