import Payments
import SwiftUI

struct EmbeddedCheckoutItemCountRowView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    var itemCount: Int {
        orderManager.order?.itemCount ?? 0
    }

    var body: some View {
        EmbeddedCheckoutInvoiceKeyValueRow(label: "Item count", value: String(itemCount), link: nil)
    }
}
