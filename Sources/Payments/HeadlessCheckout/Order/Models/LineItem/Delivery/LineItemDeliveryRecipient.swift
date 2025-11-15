import Foundation
import Utils
import Wallet

public struct LineItemDeliveryWalletAddressRecipient: Codable, Sendable {
    public var walletAddress: String
    public var locator: WalletLocator
    public var physicalAddress: PhysicalAddress?
}

public struct LineItemDeliveryEmailRecipient: Codable, Sendable {
    public var walletAddress: String
    public var locator: WalletLocator
    public var physicalAddress: PhysicalAddress?
    public var email: String
}

public enum LineItemDeliveryRecipient: Codable, Sendable {
    case walletOnly(LineItemDeliveryWalletAddressRecipient)
    case withEmail(LineItemDeliveryEmailRecipient)

    public init(from decoder: Decoder) throws {
        let lineItemDeliveryRecipient = try? when(decoder, containsKey: "email").decodeItAs(
            LineItemDeliveryEmailRecipient.self,
            andRun: { LineItemDeliveryRecipient.withEmail($0) }
        ).elseDecodeItAs(
            LineItemDeliveryWalletAddressRecipient.self,
            andRun: { LineItemDeliveryRecipient.walletOnly($0) }
        ).value

        guard let recipient = lineItemDeliveryRecipient else {
            throw DecodingError.typeMismatch(
                LineItemDeliveryRecipient.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid LineItemDeliveryRecipient"
                )
            )
        }
        self = recipient
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .walletOnly(let recipient): try container.encode(recipient)
        case .withEmail(let recipient): try container.encode(recipient)
        }
    }

    public var walletAddress: String {
        switch self {
        case .walletOnly(let recipient): recipient.walletAddress
        case .withEmail(let recipient): recipient.walletAddress
        }
    }

    public var locator: WalletLocator {
        switch self {
        case .walletOnly(let recipient): recipient.locator
        case .withEmail(let recipient): recipient.locator
        }
    }

    public var physicalAddress: PhysicalAddress? {
        switch self {
        case .walletOnly(let recipient): recipient.physicalAddress
        case .withEmail(let recipient): recipient.physicalAddress
        }
    }

    public var email: String? {
        switch self {
        case .walletOnly: nil
        case .withEmail(let recipient): recipient.email
        }
    }
}
