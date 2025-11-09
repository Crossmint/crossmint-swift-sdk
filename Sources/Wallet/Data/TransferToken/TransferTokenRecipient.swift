import CrossmintCommonTypes
import Foundation
import Utils

public enum TransferTokenRecipient: CustomStringConvertible, Equatable, Hashable, Encodable {
    public enum OptionalChain: CustomStringConvertible, Equatable, Hashable {
        case just(NonEmptyString)
        case withChain(NonEmptyString, chain: Chain)

        public var description: String {
            switch self {
            case let .just(value):
                return "\(value)"
            case let .withChain(value, chain):
                return "\(value):\(chain.name)"
            }
        }
    }

    case address(ChainAndAddress)
    case email(OptionalChain)
    case phoneNumber(OptionalChain)
    case twitter(OptionalChain)
    case x(OptionalChain)
    case userId(OptionalChain)

    public var description: String {
        switch self {
        case .address(let chainAndAddress):
            chainAndAddress.description
        case .email(let value):
            "email:\(value.description)"
        case .phoneNumber(let value):
            "phoneNumber:\(value.description)"
        case .twitter(let value):
            "twitter:\(value.description)"
        case .x(let value):
            "x:\(value)"
        case .userId(let value):
            "userId:\(value.description)"
        }
    }

    public func matches(_ string: String) -> Bool {
        return self.description == string
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.description)
    }
}

extension TransferTokenRecipient {
    public static func == (lhs: TransferTokenRecipient, rhs: String) -> Bool {
        return lhs.matches(rhs)
    }

    public static func == (lhs: String, rhs: TransferTokenRecipient) -> Bool {
        return rhs.matches(lhs)
    }

    public static func != (lhs: TransferTokenRecipient, rhs: String) -> Bool {
        return !lhs.matches(rhs)
    }

    public static func != (lhs: String, rhs: TransferTokenRecipient) -> Bool {
        return !rhs.matches(lhs)
    }

    public static func == (lhs: TransferTokenRecipient, rhs: NonEmptyString) -> Bool {
        return lhs.matches(rhs.stringValue)
    }

    public static func == (lhs: NonEmptyString, rhs: TransferTokenRecipient) -> Bool {
        return rhs.matches(lhs.stringValue)
    }

    public static func != (lhs: TransferTokenRecipient, rhs: NonEmptyString) -> Bool {
        return !lhs.matches(rhs.stringValue)
    }

    public static func != (lhs: NonEmptyString, rhs: TransferTokenRecipient) -> Bool {
        return !rhs.matches(lhs.stringValue)
    }
}
