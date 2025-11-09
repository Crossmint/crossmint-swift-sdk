import CrossmintService
import Logger
import Payments
import SwiftUI

public struct CrossmintEmbeddedCheckoutView: View {
    @StateObject private var orderManager: HeadlessCheckoutOrderManager
    @StateObject private var embeddedCheckoutStateManager: EmbeddedCheckoutStateManager
    @StateObject private var allowedPaymentMethodManager:
        EmbeddedCheckoutAllowedPaymentMethodManager

    private let createOrderInput: HeadlessCheckoutCreateOrderInput

    public init(
        crossmintService: CrossmintService,
        createOrderInput: HeadlessCheckoutCreateOrderInput,
        allowedPaymentMethods: [EmbeddedCheckoutLocalPaymentMethod]
    ) {
        self.createOrderInput = createOrderInput
        let initialReceiptEmail = createOrderInput.payment.receiptEmail ?? ""

        // TODO will need to handle case where payment method is not enabled
        let initialPaymentMethod: EmbeddedCheckoutLocalPaymentMethod = {
            switch createOrderInput.payment {
            case .checkoutcomPaymentInput:
                return .card
            // TODO uncomment when the integration is ready
            // case .stripePaymentInput:
            //     return .card
            // case .cryptoPaymentInput:
            //     return .crypto
            }
        }()

        let checkoutStateManager = EmbeddedCheckoutStateManager(
            paymentMethod: initialPaymentMethod,
            receiptEmail: initialReceiptEmail)

        self._embeddedCheckoutStateManager = StateObject(
            wrappedValue: checkoutStateManager
        )

        self._orderManager = StateObject(
            wrappedValue: HeadlessCheckoutOrderManager(
                crossmintService: crossmintService,
                checkoutStateManager: checkoutStateManager)
        )

        self._allowedPaymentMethodManager = StateObject(
            wrappedValue: EmbeddedCheckoutAllowedPaymentMethodManager(
                allowedPaymentMethods: allowedPaymentMethods
            )
        )
    }

    public var body: some View {
        HeadlessOrderRouterView().environmentObject(orderManager).environmentObject(
            embeddedCheckoutStateManager
        ).environmentObject(allowedPaymentMethodManager).task {
            do {
                guard orderManager.order == nil else {
                    Logger.paymentsUI.info(
                        "[CrossmintEmbeddedCheckoutView]: Order already exists, skipping creation")
                    return
                }

                _ = try await orderManager.createOrder(input: createOrderInput)
            } catch {
                Logger.paymentsUI.error(
                    "[CrossmintEmbeddedCheckoutView]: Failed to create order: \(error)")
            }
        }
    }
}
