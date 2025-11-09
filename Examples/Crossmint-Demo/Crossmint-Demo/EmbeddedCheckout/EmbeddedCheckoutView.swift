import CrossmintClient
import CrossmintCommonTypes
import Payments
import PaymentsUI
import SwiftUI

public struct EmbeddedCheckoutView: View {
    let createOrderInput: HeadlessCheckoutCreateOrderInput

    init?(executionMode: ExecutionMode) {
        // Initialize createOrderInput
        switch executionMode {
        case .exactOut:
            guard let orderInput = Self.createExactOutOrder() else {
                return nil
            }
            self.createOrderInput = orderInput
        case .exactIn:
            guard let orderInput = Self.createExactInOrder() else {
                return nil
            }
            self.createOrderInput = orderInput
        }

        // Log the order input once created
        Self.logOrderDetails(self.createOrderInput)
    }

    private static func createExactOutOrder() -> HeadlessCheckoutCreateOrderInput? {
        // Email recipient setup
        let emailWithoutAddress = EmailWithOptionalPhysicalAddressRecipient(
            email: "test@paella.dev")
        let recipient = RecipientInput.emailWithOptionalPhysicalAddress(emailWithoutAddress)

        // Payment setup
        let checkoutPayment = CheckoutcomPaymentInput(
            receiptEmail: "test@paella.dev", method: .checkoutComFlow)
        let payment = PaymentInput.checkoutcomPaymentInput(checkoutPayment)

        // Line items setup
        do {
            let callData = CallData(["totalPrice": "0.001", "quantity": 4])
            let collectionLocator = try CollectionLocator(
                locator: "crossmint:6caf42b6-8d1a-48f1-b47a-dd6599233b3a")
            let lineItem = WithCollectionLocator(
                collectionLocator: collectionLocator, callData: callData)
            let lineItems = try CreateOrderLineItems(items: [.withCollectionLocator(lineItem)])

            return HeadlessCheckoutCreateOrderInput(
                recipient: recipient,
                locale: Payments.Locale.enUS,
                payment: payment,
                lineItems: lineItems
            )
        } catch {
            print("[EmbeddedCheckoutView] Failed to create exact out order: \(error)")
            return nil
        }
    }

    private static func createExactInOrder() -> HeadlessCheckoutCreateOrderInput? {
        do {
            // Recipient setup
            let recipient: RecipientInput = RecipientInput.walletAddressWithOptionalPhysicalAddress(
                WalletAddressWithOptionalPhysicalAddressRecipient(
                    walletAddress: try Address(
                        address: "9NP8bWESotg1bTsyD43aHsYqekVEc88ywWXXq9dueyhz"),
                    physicalAddress: nil)
            )

            // Payment setup
            let checkoutPayment = CheckoutcomPaymentInput(
                receiptEmail: "test@paella.dev", method: .checkoutComFlow)
            let payment = PaymentInput.checkoutcomPaymentInput(checkoutPayment)

            // Line items setup
            let executionParameters = ExecutionParameters([
                "mode": "exact-in", "amount": "1", "maxSlippageBps": "500"
            ])
            let tokenLocatorLineItem = WithTokenLocator(
                tokenLocator: try TokenLocator(
                    string: "solana:4zMMC9srt5Ri5X14GAgXhaHii3GnPAEERYPJgZJDncDU"),
                callData: nil,
                executionParameters: executionParameters)

            let lineItems = try CreateOrderLineItems(items: [
                .withTokenLocator(tokenLocatorLineItem)
            ])

            return HeadlessCheckoutCreateOrderInput(
                recipient: recipient,
                locale: Payments.Locale.enUS,
                payment: payment,
                lineItems: lineItems
            )
        } catch {
            print("[EmbeddedCheckoutView] Failed to create exact in order: \(error)")
            return nil
        }
    }

    private static func logOrderDetails(_ orderInput: HeadlessCheckoutCreateOrderInput) {
        print("[EmbeddedCheckoutView] CreateOrderInput as JSON:")
        print(orderInput.json(prettyPrinted: true))
    }

    public var body: some View {
        CrossmintEmbeddedCheckoutView(
            crossmintService: CrossmintSDK.shared.crossmintService,
            createOrderInput: createOrderInput,
            allowedPaymentMethods: [.card, .crypto, .expressCheckout(.applePay)]
        )
    }
}
