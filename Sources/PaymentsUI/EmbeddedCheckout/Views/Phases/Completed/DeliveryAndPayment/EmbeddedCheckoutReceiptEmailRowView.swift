import Payments
import SwiftUI

struct EmbeddedCheckoutReceiptEmailRowView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var receiptEmail: String? {
        orderManager.order?.payment.receiptEmail
    }

    var body: some View {
        if receiptEmail == nil {
            EmptyView()
        } else {
            EmbeddedCheckoutInvoiceKeyValueRow(
                label: "Receipt sent to",
                value: receiptEmail ?? "",
                link: nil
            )
        }
    }
}
