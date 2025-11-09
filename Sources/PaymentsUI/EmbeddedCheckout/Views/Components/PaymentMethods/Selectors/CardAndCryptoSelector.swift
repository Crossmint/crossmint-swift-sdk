import Payments
import SwiftUI

struct CardAndCryptoSelector: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CardSelectorPaymentMethod()
            CryptoSelectorPaymentMethod()
            Spacer()
        }
    }
}
