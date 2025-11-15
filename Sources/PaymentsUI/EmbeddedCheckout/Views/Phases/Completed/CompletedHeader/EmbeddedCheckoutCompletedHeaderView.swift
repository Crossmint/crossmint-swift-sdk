import Payments
import SwiftUI

struct EmbeddedCheckoutCompletedHeaderView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var exactInOrderFailure: Bool {
        orderManager.order?.lineItems.first?.delivery.failed?.failureReason?.code
            == .slippageToleranceExceeded
    }

    var body: some View {
        if orderManager.order?.areAllLineItemsFailed == false {
            EmbeddedCheckoutSuccessHeaderView()
        } else if exactInOrderFailure {
            EmbeddedCheckoutExactInOrderFailedHeaderView()
        } else {
            EmbeddedCheckoutFailedHeaderView()
        }
    }
}
