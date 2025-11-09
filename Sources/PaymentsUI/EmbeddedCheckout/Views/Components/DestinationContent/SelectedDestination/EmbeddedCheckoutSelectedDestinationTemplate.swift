import CrossmintService
import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutSelectedDestinationTemplate: View {
    let icon: Image
    let title: String
    let subTitle: String
    @EnvironmentObject private var stateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject private var orderManager: HeadlessCheckoutOrderManager

    private var isDisabled: Bool {
        orderManager.isUpdatingOrder || orderManager.isPolling || stateManager.submitInProgress
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Icon container
                icon
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(Color(hex: "#F4F5F6"))
                    )

                // Title and subtitle container
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subTitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Change destination button
                if !isDisabled {
                    Button(action: {
                        stateManager.isEditingDestination = true
                    }) {
                        Text("Change")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(hex: "#F4F5F6"))
                            )
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#D0D5DD"), lineWidth: 1)
            )
        }
    }
}

#Preview {
    let stateManager = EmbeddedCheckoutStateManager(
        paymentMethod: .card,
        receiptEmail: nil
    )

    if let apiKey = try? ApiKey(key: "ck_test_1234567890") {

        let crossmintService = DefaultCrossmintService(apiKey: apiKey, appIdentifier: "")

        let orderManager = HeadlessCheckoutOrderManager(
            crossmintService: crossmintService,
            checkoutStateManager: stateManager
        )
        EmbeddedCheckoutSelectedDestinationTemplate(
            icon: Image(systemName: "location.fill"),
            title: "123 Main St",
            subTitle: "New York, NY 10001"
        )
        .environmentObject(stateManager)
        .environmentObject(orderManager)
    } else {
        EmptyView()
    }

}
