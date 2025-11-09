import SwiftUI

struct EmbeddedCheckoutDeliveryView: View {
    // TODO depending if the delivery is taking too long, we should show a different view
    var body: some View {
        EmbeddedCheckoutInProgressDeliveryView()
    }
}

#Preview {
    EmbeddedCheckoutDeliveryView()
}
