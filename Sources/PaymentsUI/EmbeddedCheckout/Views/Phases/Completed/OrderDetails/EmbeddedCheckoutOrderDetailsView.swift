import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutOrderDetailsView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var body: some View {
        if orderManager.order?.orderModeExactIn == true {
            EmptyView()
        } else {
            VStack(spacing: 8) {
                EmbeddedCheckoutInvoiceTitleView("Order details")
                EmbeddedCheckoutItemCountRowView()
                EmbeddedCheckoutGasFeesRowView()
                EmbeddedCheckoutTotalPriceRowView()
            }
        }
    }
}
