import SwiftUI

struct EmbeddedCheckoutFailedHeaderView: View {
    var body: some View {
        // TODO use localization
        EmbeddedCheckoutCompletedHeaderTemplateView(
            icon: Image("frownyFaceIcon", bundle: .module),
            headerText: "Your order couldn't be fulfilled",
            subtitleText: nil,
            secondarySubitleText: nil
        )
    }
}

#Preview {
    EmbeddedCheckoutFailedHeaderView()
}
