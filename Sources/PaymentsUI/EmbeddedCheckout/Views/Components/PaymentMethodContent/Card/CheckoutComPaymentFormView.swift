import Logger
import Payments
import SwiftUI

struct CheckoutComPaymentFormView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var formManager: CheckoutComPaymentFormManager

    public init() {}

    var body: some View {
        VStack {
            if orderManager.order?.payment == nil {
                EmptyView()
            } else {
                if let componentsView = formManager.checkoutComponentsView {
                    // Render the components view. Submit button can be rendered independently of this view
                    componentsView
                } else {
                    EmptyView()
                }
            }
        }.task {
            await formManager.makeComponent(
                order: orderManager.order,
                forProductionEnvironment: orderManager.isProductionEnvironment)
        }
    }
}

#Preview {
    CheckoutComPaymentFormView()
}
