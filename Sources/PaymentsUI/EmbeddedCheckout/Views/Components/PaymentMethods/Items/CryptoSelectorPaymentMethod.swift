import SwiftUI

struct CryptoSelectorPaymentMethod: View {
    var body: some View {
        GenericPaymentMethod(
            paymentMethodIcon: Image("crypto", bundle: .module),
            textToDisplay: "Crypto",
            paymentMethod: .crypto
        )
    }
}
