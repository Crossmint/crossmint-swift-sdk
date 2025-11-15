import Payments
import SwiftUI

struct EmbeddedCheckoutTotalPriceRowView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var displayablePrice: String {
        if let totalPrice = orderManager.order?.quote.totalPrice {
            return totalPrice.displayableNumericPrice()
        }
        return ""
    }

    var body: some View {
        if orderManager.order?.quote.totalPrice == nil {
            EmptyView()
        } else {
            EmbeddedCheckoutInvoiceKeyValueRow(
                label: "Total", value: displayablePrice, link: nil, isBold: true)
        }
    }
}
