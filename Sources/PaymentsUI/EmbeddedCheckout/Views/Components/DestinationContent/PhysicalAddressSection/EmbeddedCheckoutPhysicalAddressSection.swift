import Payments
import SwiftUI

// TODO implement
struct EmbeddedCheckoutPhysicalAddressSection: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager

    var physicalAddress: PhysicalAddress? {
        // TODO implement
        return nil
    }

    var body: some View {
        if let physicalAddress = physicalAddress {
            EmbeddedCheckoutPhysicalAddressForm(defaultAddress: physicalAddress)
        } else if orderManager.order?.quote.status == .requiresPhysicalAddress {
            EmbeddedCheckoutPhysicalAddressForm()
        } else {
            EmptyView()
        }
    }
}
