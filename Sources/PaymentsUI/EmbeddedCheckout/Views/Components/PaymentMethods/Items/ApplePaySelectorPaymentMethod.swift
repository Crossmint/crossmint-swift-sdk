import SwiftUI

struct ApplePaySelectorPaymentMethod: View {
    var body: some View {
        GenericPaymentMethod(
            paymentMethodIcon: Image("applePay", bundle: .module),
            textToDisplay: "Pay",
            paymentMethod: .expressCheckout(.applePay)
        )
    }
}

#Preview {
    ApplePaySelectorPaymentMethod()
}
