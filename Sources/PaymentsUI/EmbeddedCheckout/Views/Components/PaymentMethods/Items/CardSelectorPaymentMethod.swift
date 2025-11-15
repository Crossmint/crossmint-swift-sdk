import SwiftUI

struct CardSelectorPaymentMethod: View {
    var body: some View {
        GenericPaymentMethod(
            paymentMethodIcon: Image("creditCard", bundle: .module),
            textToDisplay: "Card",
            paymentMethod: .card
        )
    }
}
