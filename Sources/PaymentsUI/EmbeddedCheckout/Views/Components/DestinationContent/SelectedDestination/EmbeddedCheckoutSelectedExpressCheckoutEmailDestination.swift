import Payments
import SwiftUI

// TODO: implement
struct EmbeddedCheckoutSelectedExpressCheckoutEmailDestination: View {
    let method: EmbeddedCheckoutLocalExpressPaymentMethod
    @EnvironmentObject var stateManager: EmbeddedCheckoutStateManager

    var body: some View {
        EmptyView()
    }

    private func getDisplayText() -> String {
        switch method {
        case .applePay:
            return "Apple Pay"
        }
    }
}
