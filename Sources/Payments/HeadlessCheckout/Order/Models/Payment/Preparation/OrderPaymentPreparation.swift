import Utils

public enum OrderPaymentPreparation: Codable, Sendable {
    case cryptoOrderPaymentPreparation(CryptoOrderPaymentPreparation)
    case checkoutcomOrderPaymentPreparation(CheckoutcomOrderPaymentPreparation)
    case stripeOrderPaymentPreparation(StripeOrderPaymentPreparation)
    case kycRequiredOrderPaymentPreparation(KycRequiredPaymentPreparation)

    public init(from decoder: Decoder) throws {
        if let checkOutComOrder = try? when(
            decoder, containsKey: "checkoutcomPaymentSession"
        ).decodeItAs(
            CheckoutcomOrderPaymentPreparation.self,
            andRun: { OrderPaymentPreparation.checkoutcomOrderPaymentPreparation($0) }
        ).value {
            self = checkOutComOrder
        } else if let stripeOrder = try? when(
            decoder, containsKey: "stripePublishableKey"
        ).decodeItAs(
            StripeOrderPaymentPreparation.self,
            andRun: { OrderPaymentPreparation.stripeOrderPaymentPreparation($0) }
        ).value {
            self = stripeOrder
        } else if let cryptoOrder = try? when(
            decoder, containsKey: "serializedTransaction"
        ).decodeItAs(
            CryptoOrderPaymentPreparation.self,
            andRun: { OrderPaymentPreparation.cryptoOrderPaymentPreparation($0) }
        ).value {
            self = cryptoOrder
        } else if let kycRequiredOrder = try? when(
            decoder, containsKey: "kyc"
        ).decodeItAs(
            KycRequiredPaymentPreparation.self,
            andRun: { OrderPaymentPreparation.kycRequiredOrderPaymentPreparation($0) }
        ).value {
            self = kycRequiredOrder
        } else {
            throw DecodingError.typeMismatch(
                OrderPaymentPreparation.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Cannot decode OrderPaymentPreparation"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .cryptoOrderPaymentPreparation(let crypto):
            try container.encode(crypto)
        case .checkoutcomOrderPaymentPreparation(let checkoutcom):
            try container.encode(checkoutcom)
        case .stripeOrderPaymentPreparation(let stripe):
            try container.encode(stripe)
        case .kycRequiredOrderPaymentPreparation(let kycRequired):
            try container.encode(kycRequired)
        }
    }
}
