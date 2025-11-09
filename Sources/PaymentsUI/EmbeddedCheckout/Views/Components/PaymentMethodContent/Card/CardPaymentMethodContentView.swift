import Logger
import Payments
import SwiftUI
import Utils

struct CardHeaderView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var body: some View {
        if orderManager.order == nil {
            EmptyView()
        } else {
            VStack(alignment: .leading) {
                EmbeddedCheckoutLabel("Enter your card information")
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct CardPaymentMethodContentView: View {
    // TODO Check which payment provider we are using and use a subview
    @StateObject private var checkoutComFormManager = CheckoutComPaymentFormManager()
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager

    func validateDestination() -> Bool {
        Logger.paymentsUI.debug(
            "[CardPaymentMethodContentView.validateDestination] Validating destination: \(checkoutStateManager.destinationState.value)"
        )

        if !checkoutStateManager.isEditingDestination {
            Logger.paymentsUI.debug(
                "[CardPaymentMethodContentView.validateDestination] Valid destination: Destination is not being edited"
            )
            return true
        }

        guard let deliveryChain = orderManager.order?.lineItemDeliveryChain else {
            Logger.paymentsUI.debug(
                "[CardPaymentMethodContentView.validateDestination] Invalid destination: Delivery chain not found"
            )
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
            Logger.paymentsUI.debug(
                "[CardPaymentMethodContentView.validateDestination] Invalid destination: \(errorMessage)"
            )

            return false
        }

        Logger.paymentsUI.debug(
            "[CardPaymentMethodContentView.validateDestination] Valid destination)"
        )

        return true
    }

    func validateReceiptEmail() -> Bool {
        let allowEmptyEmail = false
        let receiptEmail = checkoutStateManager.receiptEmailState.value

        Logger.paymentsUI.debug(
            "[CardPaymentMethodContentView.validateReceiptEmail] Validating receipt email: \(receiptEmail)"
        )

        if allowEmptyEmail && isEmpty(receiptEmail) {
            Logger.paymentsUI.debug(
                "[CardPaymentMethodContentView.validateReceiptEmail] Valid receipt email: Empty email allowed"
            )
            return true
        }

        let validationResult = validateEmail(email: receiptEmail)
        if case .invalid(let errorMessage) = validationResult {
            checkoutStateManager.receiptEmailState = EmbeddedCheckoutLocalInputState(
                value: receiptEmail,
                errorMessage: errorMessage
            )
            Logger.paymentsUI.debug(
                "[CardPaymentMethodContentView.validateReceiptEmail] Invalid receipt email: \(errorMessage)"
            )
            return false
        }

        Logger.paymentsUI.debug(
            "[CardPaymentMethodContentView.validateReceiptEmail] Valid receipt email"
        )

        return true
    }

    private func handleSubmitPayment() async -> Bool {
        guard orderManager.order != nil else {
            checkoutStateManager.globalMessage = EmbeddedCheckoutGlobalMessage(
                message: "Order not loaded. Please try again.",
                displayLocation: .bottom,
                type: .error,
                timeout: 3.5,
                fatal: true
            )
            return false
        }

        if !validateDestination() || !validateReceiptEmail() {
            checkoutStateManager.submitInProgress = false
            return false
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
                    "[CardPaymentMethodContentView.handleSubmitPayment] Failed to update order: \(error)"
                )
            }
        }

        Logger.paymentsUI.info(
            "[CardPaymentMethodContentView.handleSubmitPayment] Submitting payment with checkout.com"
        )
        checkoutStateManager.submitInProgress = true
        orderManager.isPolling = true

        return true
    }

    public var body: some View {
        EmbeddedFatalErrorGuardView {
            VStack(spacing: 16) {
                EmbeddedCheckoutDestinationContent().padding(.bottom, 8)
                CardHeaderView()
                CheckoutComPaymentFormView().environmentObject(checkoutComFormManager)
                EmbeddedCheckoutQuoteTimerView()
                Spacer()
                CheckoutComSubmitButtonView().environmentObject(checkoutComFormManager)
            }
            .task {
                checkoutComFormManager.updateSubmitHandler(self.handleSubmitPayment)
            }
            .onChange(of: checkoutComFormManager.paymentSucceeded) { paymentSucceeded in
                if paymentSucceeded {
                    checkoutStateManager.paymentChargedWaitingCallback = true
                }
            }
        }
    }
}

#Preview {
    CardPaymentMethodContentView()
}
