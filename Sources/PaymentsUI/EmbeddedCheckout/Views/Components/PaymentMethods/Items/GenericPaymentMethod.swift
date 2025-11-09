import Payments
import SwiftUI

struct GenericPaymentMethod: View {
    @EnvironmentObject private var stateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject private var orderManager: HeadlessCheckoutOrderManager

    private let paymentMethodIcon: Image
    private let textToDisplay: String
    private let paymentMethod: EmbeddedCheckoutLocalPaymentMethod
    private let disabled: Bool?

    // TODO hardcode loading state for now.
    private let isLoading: Bool = false

    @MainActor
    private var isSelected: Bool {
        stateManager.paymentMethod == paymentMethod
    }

    @MainActor
    private var isPurchasing: Bool {
        stateManager.submitInProgress || orderManager.isPolling
    }

    public init(
        paymentMethodIcon: Image,
        textToDisplay: String,
        paymentMethod: EmbeddedCheckoutLocalPaymentMethod,
        disabled: Bool? = nil
    ) {
        self.paymentMethodIcon = paymentMethodIcon
        self.textToDisplay = textToDisplay
        self.paymentMethod = paymentMethod
        self.disabled = disabled
    }

    @MainActor
    private func handleTap() {
        guard !isLoading && !isPurchasing else {
            return
        }

        stateManager.paymentMethod = self.paymentMethod
    }

    var body: some View {
        Button(
            action: {
                if !isLoading {
                    handleTap()
                }
            },
            label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    isSelected ? Color.green : Color.gray.opacity(0.3),
                                    lineWidth: isSelected ? 2 : 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

                    VStack(alignment: .leading, spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 28, height: 28)
                        } else {
                            paymentMethodIcon
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .opacity(isSelected || disabled != true ? 1.0 : 0.6)
                        }

                        Text(textToDisplay)
                            .font(.custom("Inter", size: 16))
                            .fontWeight(.regular)
                            .foregroundColor(Color(hex: "#00150D"))
                            .opacity(isSelected || disabled != true ? 1.0 : 0.6)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        )
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading || disabled == true || isPurchasing)
        .frame(width: 100, height: 90)
        .opacity(isSelected ? 1.0 : (disabled == true ? 0.6 : 0.8))
    }
}
