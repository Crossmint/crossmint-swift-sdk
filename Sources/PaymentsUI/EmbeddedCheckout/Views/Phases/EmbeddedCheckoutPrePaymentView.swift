import Payments
import SwiftUI

struct EmbeddedCheckoutPrePaymentView: View {
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager

    var body: some View {
        if checkoutStateManager.paymentChargedWaitingCallback {
            EmbeddedCheckoutConfirmingPaymentView()
        } else {
            EmbeddedCheckoutPrePaymentInputView()
        }
    }
}

struct EmbeddedCheckoutPrePaymentInputView: View {

    var body: some View {
        VStack(spacing: 20) {
            EmbeddedCheckoutPrepaymentTotalHeader()
            // TODO uncomment when we have more payment methods
            // PaymentMethodSelector()
            EmbeddedCheckoutGlobalMessageView(displayLocation: .top)
            PaymentMethodContentView()
            EmbeddedCheckoutFooter()
        }.padding(.horizontal)
    }
}
