import Payments
import SwiftUI

struct PaymentMethodSelector: View {
    @EnvironmentObject private var stateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject private var allowedPaymentMethodManager:
        EmbeddedCheckoutAllowedPaymentMethodManager

    public var body: some View {
        if allowedPaymentMethodManager.allowedPaymentMethods.isEmpty {
            // Display an error message if no payment methods are enabled
            EmptyView()
                .task {
                    stateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
                        message: "No payment methods are enabled",
                        displayLocation: .top,
                        type: .error,
                        timeout: nil,
                        fatal: true
                    )
                }
        } else if allowedPaymentMethodManager.allowedPaymentMethods.count == 1 {
            // If only one payment method is enabled, don't show the selector
            EmptyView()
        } else {
            if !allowedPaymentMethodManager.isExpressCheckoutAllowed {
                // If express checkout is not available, show just card and crypto
                CardAndCryptoSelector()
            } else {
                // If express checkout is available, show all options
                CardAndCryptoAndExpressCheckoutSelector()
            }
        }
    }
}
