import CrossmintCommonTypes
import Payments
import SwiftUI
import Utils

struct EmbeddedCheckoutDeliveredToRowView: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var deliveryChain: Chain? {
        orderManager.order?.lineItemDeliveryChain
    }

    var recipient: LineItemDeliveryRecipient? {
        orderManager.order?.lineItemDeliveryRecipient
    }

    // TODO getBlockchainExplorerURL explorer link
    var explorerLink: String {
        return "DUMMY EXPLORER LINK"
    }

    var body: some View {
        if deliveryChain == nil || recipient == nil {
            EmptyView()
        } else {
            if let physicalAddress = recipient?.physicalAddress {
                // Physical address
                EmbeddedCheckoutInvoiceKeyValueRow(
                    label: "Delivered to",
                    value: physicalAddress.line1,
                    link: nil
                )
            } else if let walletAddress = recipient?.walletAddress {
                // Wallet address
                EmbeddedCheckoutInvoiceKeyValueRow(
                    label: "Delivered to",
                    value: cutMiddleAndAddEllipsis(
                        walletAddress, beginLength: 6, endLength: 6),
                    link: nil
                )
            } else {
                EmptyView()
            }
        }
    }
}
