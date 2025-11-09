import Payments
import SwiftUI

struct EmbeddedCheckoutDestinationLabel: View {
    // TODO: use appearance manager
    // TODO: use DestinationContentManager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager
    var isExpressCheckoutEmailDestination: Bool = false

    // TODO use DestinationContentManager to check if we hide the destination content

    private var destinationText: String {
        // TODO use localization
        let orderRecipientDestination =
            orderManager.order?.lineItemDeliveryRecipient != nil
            && !checkoutStateManager.isEditingDestination

        if orderRecipientDestination || isExpressCheckoutEmailDestination {
            if let multiTokenOrder = orderManager.order?.isMultiTokenOrder {
                return multiTokenOrder ? "Delivering items to" : "Delivering item to"
            } else {
                return "Delivering item to"
            }
        }

        return "Choose delivery method"
    }

    var body: some View {
        EmbeddedCheckoutLabel(destinationText)
    }

}
