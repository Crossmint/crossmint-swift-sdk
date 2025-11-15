import Payments
import SwiftUI

struct EmbeddedCheckoutSuccessHeaderView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var totalPrice: Price {
        orderManager.order?.quote.totalPrice ?? Price(amount: "0", currency: .fiat(.usd))
    }

    var body: some View {
        EmbeddedCheckoutCompletedHeaderTemplateView(
            icon: Image("checkIcon", bundle: .module),
            headerText: "Thank you for your order",
            subtitleText: totalPrice.displayableNumericPrice(),
            secondarySubitleText: orderManager.order?.tokenQuantityAndName
        )
    }
}
