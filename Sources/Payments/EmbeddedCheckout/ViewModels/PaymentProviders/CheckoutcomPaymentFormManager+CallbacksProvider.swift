import Logger

#if canImport(CheckoutComponents)
    import CheckoutComponents
#elseif canImport(CheckoutComponentsSDK)
    import CheckoutComponentsSDK
#endif

// MARK: - Callback Handlers

extension CheckoutComPaymentFormManager {
    func initialiseCallbacks() -> CheckoutComponents.Callbacks {
        .init(
            onReady: { paymentMethod in
                Logger.payments.info(
                    "[CheckoutComPaymentFormManager.CallbacksProvider.onReady] Payment method: \(paymentMethod.name)"
                )
            },
            handleTap: { [weak self] paymentMethod async -> Bool in
                Logger.payments.info(
                    "[CheckoutComPaymentFormManager.CallbacksProvider.handleTap] Payment method: \(paymentMethod.name)"
                )

                guard let self = self else { return false }

                // Run on MainActor through Task to handle the actor-isolation properly
                return await Task { @MainActor in
                    return await self.handleSubmitPayment()
                }.value
            },
            onSubmit: { paymentMethod in
                Logger.payments.info(
                    "[CheckoutComPaymentFormManager.CallbacksProvider.onSubmit] Payment method: \(paymentMethod.name)"
                )
            },
            onTokenized: { [weak self] tokenDetails in
                Logger.payments.info(
                    "[CheckoutComPaymentFormManager.CallbacksProvider.onTokenized] Token: \(tokenDetails.data.token)"
                )

                guard let self = self else { return CheckoutComponents.CallbackResult.rejected(message: nil) }

                Task {
                    let showingPayButton = await MainActor.run { self.showPayButton }
                    guard !showingPayButton else {
                        Logger.payments.info(
                            "[CheckoutComPaymentFormManager.CallbacksProvider.onTokenized] Showing checkout.com Flow element payment button. Skipping payment submission"
                        )
                        return
                    }

                    // Access actor-isolated property on the main actor
                    let orderToProcess = await MainActor.run { self.processingOrder }

                    guard let order = orderToProcess else {
                        Logger.payments.error(
                            "[CheckoutComPaymentFormManager.CallbacksProvider.onTokenized] Tokenized event received but no order to process"
                        )
                        return
                    }

                    do {
                        let paymentResponse = try await self.checkoutComAdapter.submitPayment(
                            withToken: tokenDetails, forOrder: order)

                        Logger.payments.debug(
                            "[CheckoutComPaymentFormManager.CallbacksProvider.onTokenized] Payment response: \(paymentResponse.json(prettyPrinted: true))"
                        )
                    } catch {
                        // TODO update global message state
                        Logger.payments.error(
                            "[CheckoutComPaymentFormManager.CallbacksProvider.onTokenized] Failed to submit payment: \(error.localizedDescription)"
                        )
                    }
                }

                return CheckoutComponents.CallbackResult.accepted
            },
            onSuccess: { [weak self] paymentMethod, paymentID in
                guard let self else { return }

                Task { @MainActor in
                    self.handleOnSuccess(paymentMethod, paymentID)
                }
            },
            onError: { [weak self] error in
                guard let self else { return }

                Task { @MainActor in
                    self.handleOnError(error)
                }
            }
        )
    }

    func handleOnSuccess(_ paymentMethod: CheckoutComponents.Describable, _ paymentId: String) {
        Logger.payments.info(
            "[CheckoutComPaymentFormManager.CallbacksProvider.handleOnSuccess] Payment method: \(paymentMethod.name) ....> Payment Id: \(paymentId)"
        )
        paymentSucceeded = true
        paymentID = paymentId
        showPaymentResult = true
    }

    func handleOnError(_ error: CheckoutComponents.Error) {
        // TODO update global message state
        Logger.payments.error(
            "[CheckoutComPaymentFormManager.CallbacksProvider.handleOnError] \(error.errorCode.localizedDescription)"
        )
        paymentSucceeded = false
        // to avoid dismiss current 3DS challenge and showing every error message on the screen, only showing 3DS challenge that has failed authentication
        guard case let .cardAuthenticationFailed(message) = error.errorCode,
            message == "Authentication failed."
        else {
            return
        }
        paymentSucceeded = false
        paymentID = error.errorCode.localizedDescription
        showPaymentResult = true
    }
}
