import Payments
import SwiftUI

struct EmbeddedCheckoutGasFeesRowView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var displayablePrice: String {
        if let totalPrice = orderManager.order?.quote.totalPrice,
            let gasFees = orderManager.order?.gasFees {
            let priceToDisplay = Price(amount: gasFees.description, currency: totalPrice.currency)
            return priceToDisplay.displayableNumericPrice()
        }

        return ""
    }

    var zeroGasFees: Bool {
        orderManager.order?.gasFees.isZero == true
    }

    var body: some View {
        if orderManager.order?.quote.totalPrice == nil || zeroGasFees {
            EmptyView()
        } else {
            EmbeddedCheckoutInvoiceKeyValueRow(
                label: "Gas fees", value: displayablePrice, link: nil)
        }
    }
}
