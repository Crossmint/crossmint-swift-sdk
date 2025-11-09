import Payments
import SwiftUI
import Utils

public struct EmbeddedCheckoutSubmitPaymentButton: View {
    // TODO use appearance manager
    @EnvironmentObject private var checkoutStateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject private var orderManager: HeadlessCheckoutOrderManager
    let onSubmit: () -> Void
    let loading: Bool

    private let modalityText: [HeadlessCheckoutPaymentModality: String] = [
        // TODO use localization
        .oneOff: "Pay",
        .subscription: "Subscribe"
    ]

    var totalPrice: Price? {
        orderManager.order?.quote.totalPrice
    }

    var insufficientFunds: Bool {
        orderManager.order?.payment.status == .cryptoPayerInsufficientFunds
    }

    var requiresPhysicalAddress: Bool {
        orderManager.order?.quote.status == .requiresPhysicalAddress
    }

    var isDisabled: Bool {
        insufficientFunds || requiresPhysicalAddress
    }

    var isLoading: Bool {
        loading || totalPrice == nil || orderManager.isUpdatingOrder
            || checkoutStateManager.submitInProgress || orderManager.isPolling
    }

    var displayablePrice: String {
        return totalPrice?.displayableNumericPrice() ?? ""
    }

    var displayableModality: String {
        modalityText[checkoutStateManager.paymentModality] ?? "Pay"
    }

    public init(loading: Bool? = nil, onSubmit: @escaping () -> Void) {
        self.loading = loading ?? false
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack {
            EmbeddedCheckoutGlobalMessageView(displayLocation: .bottom)
            EmbeddedFatalErrorGuardView {
                Button {
                    onSubmit()
                } label: {
                    Text("\(displayableModality) \(displayablePrice)")
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(hex: "05B959"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .disabled(isDisabled)
                        .opacity(isLoading ? 0.5 : 1)
                        .font(.custom("Inter", size: 18).weight(.heavy))
                }
                .frame(width: UIScreen.main.bounds.width * 0.8)
            }
        }
    }
}
