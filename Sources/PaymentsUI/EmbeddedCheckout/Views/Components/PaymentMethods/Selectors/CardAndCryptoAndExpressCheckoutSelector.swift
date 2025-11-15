import Payments
import SwiftUI

struct CardAndCryptoAndExpressCheckoutSelector: View {
    @EnvironmentObject private var allowedPaymentMethodManager:
        EmbeddedCheckoutAllowedPaymentMethodManager

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if allowedPaymentMethodManager.isPayingCardAllowed {
                CardSelectorPaymentMethod()
            }
            if allowedPaymentMethodManager.isPayingCryptoAllowed {
                CryptoSelectorPaymentMethod()
            }
            if allowedPaymentMethodManager.isExpressCheckoutAllowed {
                ApplePaySelectorPaymentMethod()
            }
            Spacer()
        }
    }
}
