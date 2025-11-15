import SwiftUI

struct EmbeddedCheckoutDeliveryAndPaymentView: View {
    var body: some View {
        VStack(spacing: 8) {
            EmbeddedCheckoutInvoiceTitleView("Purchase info")

            EmbeddedCheckoutPaymentMethodRowView()
            EmbeddedCheckoutDeliveredToRowView()
            EmbeddedCheckoutReceiptEmailRowView()
        }
    }
}
