import Logger
import Payments
import SwiftUI
import Utils

// TODO: Implement
struct CheckoutComSubmitButtonView: View {
    @EnvironmentObject var checkoutComFormManager: CheckoutComPaymentFormManager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager

    func validateDestination() -> Bool {
        if !checkoutStateManager.isEditingDestination {
            return true
        }

        guard let deliveryChain = orderManager.order?.lineItemDeliveryChain else {
            return false
        }

        let validationResult = validateEmailOrWallet(
            emailOrWallet: checkoutStateManager.destinationState.value,
            deliveryChain: deliveryChain
        )

        if case .invalid(let errorMessage) = validationResult {
            checkoutStateManager.destinationState = EmbeddedCheckoutLocalInputState(
                value: checkoutStateManager.destinationState.value,
                errorMessage: errorMessage
            )

            return false
        }

        return true
    }

    func validateReceiptEmail() -> Bool {
        let allowEmptyEmail = false
        let receiptEmail = checkoutStateManager.receiptEmailState.value

        if allowEmptyEmail && isEmpty(receiptEmail) {
            return true
        }

        let validationResult = validateEmail(email: receiptEmail)
        if case .invalid(let errorMessage) = validationResult {
            checkoutStateManager.receiptEmailState = EmbeddedCheckoutLocalInputState(
                value: receiptEmail,
                errorMessage: errorMessage
            )

            return false
        }

        return true
    }

    private func handleSubmitPayment() async {
        guard orderManager.order != nil else {
            checkoutStateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
                message: "Order not loaded. Please try again.",
                displayLocation: .bottom,
                type: .error,
                timeout: 3.5,
                fatal: true
            )
            return
        }

        if !validateDestination() || !validateReceiptEmail() {
            checkoutStateManager.submitInProgress = false
            return
        }

        // Updating order if there is a mismatch
        if !isEmpty(checkoutStateManager.receiptEmailState.value)
            && orderManager.order?.payment.receiptEmail
                != checkoutStateManager.receiptEmailState.value {
            do {
                // TODO verify that order is updated correctly with partial update
                _ = try await orderManager.updateOrder(
                    input: HeadlessCheckoutUpdateOrderInput(
                        recipient: nil,
                        locale: nil,
                        payment: PaymentInput.checkoutcomPaymentInput(
                            CheckoutcomPaymentInput(
                                receiptEmail: checkoutStateManager.receiptEmailState.value,
                                method: .checkoutComFlow
                            )
                        )
                    )
                )
            } catch {
                Logger.paymentsUI.error(
                    "[CheckoutComSubmitButtonView.handleSubmitPayment] Failed to update order: \(error)"
                )
            }
        }

        Logger.paymentsUI.info(
            "[CheckoutComSubmitButtonView.handleSubmitPayment] Submitting payment with checkout.com"
        )
        checkoutStateManager.submitInProgress = true
        checkoutComFormManager.submitPayment()
        orderManager.isPolling = true
    }

    var body: some View {
        if checkoutComFormManager.showPayButton {
            EmptyView()
        } else {
            EmbeddedCheckoutSubmitPaymentButton {
                Task {
                    await handleSubmitPayment()
                }
            }
        }
    }
}
