import Payments
import SwiftUI

struct EmbeddedCheckoutInProgressDeliveryView: View {
    var body: some View {
        // TODO: use localizable strings
        VStack(spacing: 16) {
            Spacer()

            // Paper plane animation
            CrossmintLottieView(animationName: "paperPlane", loopMode: .loop, animationSpeed: 1)
                .frame(width: 120, height: 120)

            ProgressBar()

            // TODO update text based on number of items
            HeadingTitle(text: "Delivering your items...")
            HeadingSubtitle(text: "Less than 1 minute")

            Spacer(minLength: 40)

            Image("poweredByCrossmint", bundle: .module)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 20)
        }
        .padding()
    }
}

#Preview {
    EmbeddedCheckoutInProgressDeliveryView()
}
