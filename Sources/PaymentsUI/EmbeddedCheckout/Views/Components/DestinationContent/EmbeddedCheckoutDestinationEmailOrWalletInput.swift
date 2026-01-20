import Combine
import CrossmintCommonTypes
import Logger
import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutDestinationEmailOrWalletInput: View {
    let deliveryChain: Chain
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @State private var inputText: String = ""

    // Initialize the local state when the view appears
    private func initializeState() {
        inputText = checkoutStateManager.destinationState.value
    }

    var isDisabled: Bool {
        orderManager.isUpdatingOrder || orderManager.isPolling
            || checkoutStateManager.submitInProgress
    }

    // TODO use DestinationStateManager to determine if we should hide this view

    private func updateOrderRecipient(newRecipient: RecipientInput) async {
        do {
            // orderManager.updateOrder will update the global message if there is an error
            _ = try await self.orderManager.updateOrder(
                input: HeadlessCheckoutUpdateOrderInput(
                    recipient: newRecipient, locale: nil, payment: nil
                )
            )
        } catch {
            Logger.paymentsUI.error(
                "[EmbeddedCheckoutDestinationEmailOrWalletInput.updateOrderRecipient] " +
                "Error updating recipient: \(error)"
            )
        }

        checkoutStateManager.isEditingDestination = false
        checkoutStateManager.destinationState = EmbeddedCheckoutLocalInputState(
            value: "", errorMessage: nil)
    }

    private func handleLiveEmailOrWalletChange(_ newValue: String) {
        Logger.paymentsUI.debug(
            "[EmbeddedCheckoutDestinationEmailOrWalletInput.handleLiveEmailOrWalletChange] " +
            "email or wallet text changed to: \(newValue)"
        )

        // Debouncing and updating the state
        checkoutStateManager.isEditingDestination = true
        checkoutStateManager.destinationState = EmbeddedCheckoutLocalInputState(
            value: newValue, errorMessage: nil
        )
    }

    private func validateNewEmailOrWalletAndUpdateRecipient(
        _ destinationState: EmbeddedCheckoutLocalInputState
    ) async {
        let value = destinationState.value

        Logger.paymentsUI.info(
            "[EmbeddedCheckoutDestinationEmailOrWalletInput.validateNewEmailOrWalletAndUpdateRecipient] " +
            "Validating and updating recipient with value: \(value)"
        )

        // If it's empty, don't modify the state
        guard !isEmpty(value) else {
            return
        }

        if let walletAddress: Address =
            Address.validateAddressAndReturnAddress(
                value, chain: deliveryChain) {
            Logger.paymentsUI.debug(
                "[EmbeddedCheckoutDestinationEmailOrWalletInput.validateNewEmailOrWalletAndUpdateRecipient] " +
                "valid wallet address: \(value)"
            )
            await updateOrderRecipient(
                newRecipient: RecipientInput.walletAddressWithOptionalPhysicalAddress(
                    WalletAddressWithOptionalPhysicalAddressRecipient(
                        walletAddress: walletAddress,
                        physicalAddress: nil
                    )
                ))
        } else if isValidEmail(value) {
            Logger.paymentsUI.debug(
                "[EmbeddedCheckoutDestinationEmailOrWalletInput.validateNewEmailOrWalletAndUpdateRecipient] " +
                "valid email: \(value)"
            )
            // TODO validate email
            await updateOrderRecipient(
                newRecipient: RecipientInput.emailWithOptionalPhysicalAddress(
                    EmailWithOptionalPhysicalAddressRecipient(
                        email: value,
                        physicalAddress: nil
                    )
                )
            )
        }
    }

    private func validateEmailOrWalletAndShowErrors() {
        Logger.paymentsUI.debug(
            "[EmbeddedCheckoutDestinationEmailOrWalletInput.validateEmailOrWalletAndShowErrors] " +
            "Validating email or wallet: \(inputText)"
        )

        let emailOrWallet = inputText

        guard !isEmpty(emailOrWallet) else {
            return
        }

        if case .invalid(let errorMessage) = validateEmailOrWallet(
            emailOrWallet: emailOrWallet, deliveryChain: deliveryChain) {
            self.checkoutStateManager.destinationState = EmbeddedCheckoutLocalInputState(
                value: emailOrWallet,
                errorMessage: errorMessage
            )
        }
    }

    private var placeholder: String {
        "Email or \(deliveryChain.name.capitalized) wallet address"
    }

    var body: some View {
        EmbeddedCheckoutInput(
            text: $inputText,  // Bind to local state instead
            placeholder: placeholder,
            isLoading: orderManager.isUpdatingOrder,
            errorMessage: checkoutStateManager.destinationState.errorMessage,
            onEditingChanged: { isEditing in
                if isEditing {
                    checkoutStateManager.isEditingDestination = true
                } else {
                    // On blur
                    validateEmailOrWalletAndShowErrors()
                }
            }
        )
        .disabled(isDisabled)
        .onChange(of: inputText, perform: handleLiveEmailOrWalletChange)
        .onAppear {
            initializeState()
        }
        .onReceive(checkoutStateManager.$debouncedDestinationState) { debouncedState in
            Logger.paymentsUI.debug(
                "[EmbeddedCheckoutDestinationEmailOrWalletInput.onReceive] " +
                "Debounced state changed to: \(debouncedState.value)"
            )

            // Validate that the debounced state is the same as the current state so we don't update the recipient twice
            guard debouncedState.value == checkoutStateManager.destinationState.value else {
                return
            }

            Task {
                await validateNewEmailOrWalletAndUpdateRecipient(debouncedState)
            }
        }
    }
}
