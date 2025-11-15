import SwiftUI

@MainActor
public final class EmbeddedCheckoutAllowedPaymentMethodManager: CheckoutAllowedPaymentMethod {
    @Published public private(set) var allowedPaymentMethods: [EmbeddedCheckoutLocalPaymentMethod]

    public init(allowedPaymentMethods: [EmbeddedCheckoutLocalPaymentMethod]) {
        self.allowedPaymentMethods = allowedPaymentMethods
    }

    public var isPayingFiatAllowed: Bool {
        return allowedPaymentMethods.contains(.card)
            || allowedPaymentMethods.contains(.expressCheckout(.applePay))
    }

    public var isPayingCardAllowed: Bool {
        return allowedPaymentMethods.contains(.card)
    }

    public var isPayingCryptoAllowed: Bool {
        return allowedPaymentMethods.contains(.crypto)
    }

    public var isExpressCheckoutAllowed: Bool {
        return allowedPaymentMethods.contains(.expressCheckout(.applePay))
    }
}
