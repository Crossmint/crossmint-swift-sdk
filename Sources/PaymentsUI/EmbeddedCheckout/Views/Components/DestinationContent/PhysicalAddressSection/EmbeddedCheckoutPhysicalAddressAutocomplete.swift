import SwiftUI
import Payments

// TODO implement
struct EmbeddedCheckoutPhysicalAddressAutocomplete: View {
    let physicalAddressWithoutName: PhysicalAddressWithoutName
    let onAddressSelected: (PhysicalAddressWithoutName) -> Void

    init(physicalAddressWithoutName: PhysicalAddressWithoutName, onAddressSelected: @escaping (PhysicalAddressWithoutName) -> Void) {
        self.physicalAddressWithoutName = physicalAddressWithoutName
        self.onAddressSelected = onAddressSelected
    }

    var body: some View {
        EmptyView()
    }
}
