public enum EmbeddedCheckoutLocalExpressPaymentMethod: String, Equatable {
    case applePay = "express-checkout::apple-pay"
}

public enum EmbeddedCheckoutLocalPaymentMethod: Equatable {
    case card
    case crypto
    case expressCheckout(EmbeddedCheckoutLocalExpressPaymentMethod)

    var applePay: EmbeddedCheckoutLocalExpressPaymentMethod? {
        switch self {
        case .expressCheckout(let method):
            return method == .applePay ? method : nil
        default:
            return nil
        }
    }
}

extension EmbeddedCheckoutLocalPaymentMethod: RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "card":
            self = .card
        case "crypto":
            self = .crypto
        case let value where value.hasPrefix("express-checkout::"):
            if let expressMethod = EmbeddedCheckoutLocalExpressPaymentMethod(rawValue: value) {
                self = .expressCheckout(expressMethod)
            } else {
                return nil
            }
        default:
            return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .card:
            return "card"
        case .crypto:
            return "crypto"
        case .expressCheckout(let method):
            return method.rawValue
        }
    }
}
