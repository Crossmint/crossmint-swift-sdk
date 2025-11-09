import Payments
import SwiftUI

struct EmbeddedCheckoutLineContentsView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var completedLineItems: [LineItem] {
        orderManager.order?.lineItems.filter { $0.delivery.delivered != nil } ?? []
    }

    var failedLineItems: [LineItem] {
        orderManager.order?.lineItems.filter { $0.delivery.failed != nil } ?? []
    }

    var body: some View {
        VStack {
            EmbeddedCheckoutCompletedLineItemsView(lineItems: completedLineItems)
            EmbeddedCheckoutFailedLineItemsView(lineItems: failedLineItems)
        }
    }
}
