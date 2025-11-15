import Payments
import SwiftUI

struct EmbeddedCheckoutFailedLineItemsView: View {
    let lineItems: [LineItem]

    var body: some View {
        if lineItems.isEmpty {
            EmptyView()
        } else {
            EmbeddedCheckoutLineItemsSectionTemplateView(title: "Unavailable items") {
                ForEach(Array(lineItems.enumerated()), id: \.element.id) { index, lineItem in
                    EmbeddedCheckoutLineItemRowView(lineItem: lineItem)

                    if index < lineItems.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }
}
