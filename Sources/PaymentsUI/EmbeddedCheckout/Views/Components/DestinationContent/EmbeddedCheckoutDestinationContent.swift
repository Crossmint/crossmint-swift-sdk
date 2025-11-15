import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutDestinationContent: View {
    @EnvironmentObject var stateManager: EmbeddedCheckoutStateManager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var expressCheckoutMethod: EmbeddedCheckoutLocalPaymentMethod?

    var body: some View {
        if orderManager.order == nil {
            EmptyView()
        } else if let recipient = orderManager.order?.lineItemDeliveryRecipient,
            !stateManager.isEditingDestination {
            EmbeddedCheckoutDestinationContentWithLabel {
                EmbeddedCheckoutPhysicalAddressSection()
                EmbeddedCheckoutSelectedDestination(recipientLocator: recipient.locator)
                // Showing the receipt email content for wallet only orders
                if case .walletOnly = recipient {
                    EmbeddedCheckoutReceiptEmailContent()
                }
            }
        } else if let expressCheckoutMethod = expressCheckoutMethod,
            case .expressCheckout(let expressMethod) = expressCheckoutMethod,
            !stateManager.isEditingDestination {
            EmbeddedCheckoutDestinationContentWithLabel(isExpressCheckoutEmailDestination: true) {
                EmbeddedCheckoutPhysicalAddressSection()
                EmbeddedCheckoutSelectedExpressCheckoutEmailDestination(
                    method: expressMethod)
            }
        } else {
            EmbeddedCheckoutDestinationContentWithLabel {
                EmbeddedCheckoutPhysicalAddressSection()
                if let chain = orderManager.order?.lineItemDeliveryChain {
                    EmbeddedCheckoutDestinationEmailOrWalletInput(deliveryChain: chain)
                }
            }
        }
    }
}

struct EmbeddedCheckoutDestinationContentWithLabel<Content: View>: View {
    var isExpressCheckoutEmailDestination: Bool = false
    let content: Content

    init(isExpressCheckoutEmailDestination: Bool = false, @ViewBuilder content: () -> Content) {
        self.isExpressCheckoutEmailDestination = isExpressCheckoutEmailDestination
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            EmbeddedCheckoutDestinationLabel(
                isExpressCheckoutEmailDestination: isExpressCheckoutEmailDestination
            )
            content
        }
    }
}
