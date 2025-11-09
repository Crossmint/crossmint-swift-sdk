import SwiftUI

struct EmbeddedCheckoutConfirmingPaymentView: View {
    var body: some View {
        VStack(spacing: 16) {
            // TODO: use localizable strings
            Spacer()
            CrossmintLottieView(
                animationName: "creditCardAnimation",
                loopMode: .loop,
                animationSpeed: 1.0
            ).frame(width: 120, height: 120)

            HeadingTitle(text: "Confirming payment...")
            HeadingSubtitle(text: "Less than 1 minute")

            Spacer(minLength: 40)

        }
        .padding()
    }
}

#Preview {
    EmbeddedCheckoutConfirmingPaymentView()
}
