import Logger
import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutReceiptEmailContent: View {
    // TODO use manager to determine if we should hide the content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EmbeddedCheckoutLabel("Send receipt to")
            EmbeddedCheckoutReceiptEmailInput()
        }
    }
}

struct EmbeddedCheckoutReceiptEmailInput: View {
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @State private var emailText: String = ""  // Initialized incorrectly

    private func initializeState() {
        emailText = checkoutStateManager.receiptEmailState.value
    }

    private var isDisabled: Bool {
        self.orderManager.isPolling || self.checkoutStateManager.submitInProgress
    }

    private func validateEmailAndShowErrors() {
        let email = emailText
        guard !isEmpty(email) else {
            return
        }

        if case .invalid(let errorMessage) = validateEmail(email: email) {
            self.checkoutStateManager.receiptEmailState = EmbeddedCheckoutLocalInputState(
                value: email,
                errorMessage: errorMessage
            )
        }
    }

    private func handleLiveEmailChange(_ newValue: String) {
        Logger.paymentsUI.debug(
            "[EmbeddedCheckoutReceiptEmailInput.handleLiveEmailChange] email text changed to: \(newValue)"
        )

        self.checkoutStateManager.receiptEmailState = EmbeddedCheckoutLocalInputState(
            value: newValue,
            errorMessage: nil
        )
    }

    var body: some View {
        EmbeddedCheckoutInput(
            text: $emailText,  // Bind to local state instead
            placeholder: "Email address",
            errorMessage: checkoutStateManager.receiptEmailState.errorMessage,
            onEditingChanged: { isEditing in
                if !isEditing {
                    // On blur
                    validateEmailAndShowErrors()
                }
            }
        )
        .disabled(isDisabled)
        .onChange(of: emailText, perform: handleLiveEmailChange)
        .onAppear(perform: initializeState)
    }
}
