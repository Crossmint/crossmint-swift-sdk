import Payments
import SwiftUI

struct EmbeddedCheckoutPaymentMethodRowView: View {
    // TODO use localization
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var cardPayment: Bool {
        orderManager.order?.payment.method.isFiat ?? true
    }

    var invoiceValue: String {
        if cardPayment {
            return "Card - \(orderManager.order?.payment.currency.name ?? "")"
        }

        if case .crypto(let cryptoMethod) = orderManager.order?.payment.method {
            return
                "\(cryptoMethod.blockChainCopy) - \(orderManager.order?.payment.currency.name ?? "")"
        }

        return ""
    }

    var body: some View {
        if orderManager.order == nil {
            EmptyView()
        } else {
            EmbeddedCheckoutInvoiceKeyValueRow(
                label: "Payment method",
                value: invoiceValue,
                link: nil
            )
        }
    }
}
