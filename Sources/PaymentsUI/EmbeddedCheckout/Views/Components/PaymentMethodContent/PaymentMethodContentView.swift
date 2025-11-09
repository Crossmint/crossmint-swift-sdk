import Logger
import Payments
import SwiftUI

public struct PaymentMethodContentView: View {
    @EnvironmentObject private var checkoutStateManager: EmbeddedCheckoutStateManager

    public init() {}

    public var body: some View {
        switch checkoutStateManager.paymentMethod {
        case .card:
            CardPaymentMethodContentView()
        case .crypto:
            CryptoPaymentMethodContentView()
        case .expressCheckout(let expressMethod):
            switch expressMethod {
                case .applePay:
                    ExpressPaymentMethodContentView(.applePay)
            }

        }
    }
}
