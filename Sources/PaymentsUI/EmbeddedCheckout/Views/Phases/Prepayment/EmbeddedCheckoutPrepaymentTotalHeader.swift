import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutPrepaymentTotalHeader: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if orderManager.order == nil {
                EmptyView()
            } else {
                Text("Checkout")
                    .font(.custom("Inter", size: 14))
                    .foregroundColor(Color(hex: "#67797F"))

                Text(orderManager.order?.quote.totalPrice?.displayableNumericPrice() ?? "")
                    .font(.custom("Inter", size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(Color(hex: "#00150D"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
