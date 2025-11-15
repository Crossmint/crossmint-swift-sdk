import Foundation

@MainActor
public protocol CheckoutAllowedPaymentMethod: ObservableObject {
    var allowedPaymentMethods: [EmbeddedCheckoutLocalPaymentMethod] { get }

    var isPayingFiatAllowed: Bool { get }
    var isPayingCardAllowed: Bool { get }
    var isPayingCryptoAllowed: Bool { get }
    var isExpressCheckoutAllowed: Bool { get }
}
