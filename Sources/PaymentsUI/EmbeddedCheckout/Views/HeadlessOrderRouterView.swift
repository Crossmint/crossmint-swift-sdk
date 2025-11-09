import Payments
import SwiftUI

public struct HeadlessOrderRouterView: View {
    @EnvironmentObject private var orderManager: HeadlessCheckoutOrderManager

    public var body: some View {
        if let order = orderManager.order {
            switch order.phase {
            case .delivery:
                EmbeddedCheckoutDeliveryView()
            case .completed:
                EmbeddedCheckoutCompletedView()
            case .payment:
                if [.requiresKyc, .failedKyc, .manualKyc].contains(order.payment.status) {
                    EmbeddedCheckoutKycView()
                } else {
                    EmbeddedCheckoutPrePaymentView()
                }
            case .quote:
                EmbeddedCheckoutPrePaymentView()
            }
        } else {
            EmbeddedCheckoutPrePaymentView()
        }
    }
}
#Preview {
    HeadlessOrderRouterView()
}
