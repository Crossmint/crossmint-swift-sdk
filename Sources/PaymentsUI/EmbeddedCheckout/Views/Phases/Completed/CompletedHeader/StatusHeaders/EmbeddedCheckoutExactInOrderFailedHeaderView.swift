import SwiftUI

struct EmbeddedCheckoutExactInOrderFailedHeaderView: View {
    var body: some View {
        VStack(spacing: 8) {
            // TODO use localization
            EmbeddedCheckoutCompletedHeaderTemplateView(
                icon: nil,
                headerText: "Your order couldn't be fulfilled",
                subtitleText: nil,
                secondarySubitleText: nil
            )

            EmbeddedCheckoutOrderWarningContainerView(
                title: "Order slippage exceeded",
                description:
                    "Your slippage limit was exceeded and we were unable to fulfill your order at the quoted amount. You have not been charged."
            )
        }
    }
}

struct EmbeddedCheckoutOrderWarningContainerView: View {
    let title: String
    let description: String

    // Colors based on the project style
    private let warningColor = Color(hex: "#FF9900")  // Yellow warning color
    private let textPrimaryColor = Color(hex: "#00150D")
    private let textSecondaryColor = Color(hex: "#67797F")
    private let backgroundPrimaryColor = Color.white

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            RefundIcon()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textPrimaryColor)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(textSecondaryColor)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(warningColor, lineWidth: 1)
        )
    }
}

struct RefundIcon: View {
    var body: some View {
        Image("refundIcon", bundle: .module)
            .foregroundColor(.white)
    }
}

#Preview {
    EmbeddedCheckoutExactInOrderFailedHeaderView()
}
