import Payments
import SwiftUI

// TODO implement
struct EmbeddedCheckoutPhysicalAddressInput: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager
    let physicalAddressWithoutName: PhysicalAddressWithoutName
    let onPhysicalAddressChange: (PhysicalAddressWithoutName) -> Void

    var isDisabled: Bool {
        self.orderManager.isUpdatingOrder || self.orderManager.isPolling
            || self.checkoutStateManager.submitInProgress
    }

    init(
        physicalAddressWithoutName: PhysicalAddressWithoutName,
        onPhysicalAddressChange: @escaping (PhysicalAddressWithoutName) -> Void
    ) {
        self.physicalAddressWithoutName = physicalAddressWithoutName
        self.onPhysicalAddressChange = onPhysicalAddressChange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Address autocomplete
            EmbeddedCheckoutPhysicalAddressAutocomplete(
                physicalAddressWithoutName: physicalAddressWithoutName,
                onAddressSelected: { selectedAddress in
                    // Similar to the React version, when a new address is selected,
                    // clear line2 as it likely won't correspond to the new address
                    var updatedAddress = selectedAddress
                    updatedAddress.line2 = ""
                    onPhysicalAddressChange(updatedAddress)
                }
            )

            // Apt, suite, unit field (similar to line2 in the React version)
            if physicalAddressWithoutName.line1.isEmpty == false {
                EmbeddedCheckoutInput(
                    text: Binding(
                        get: { physicalAddressWithoutName.line2 ?? "" },
                        set: { newValue in
                            var updatedAddress = physicalAddressWithoutName
                            updatedAddress.line2 = newValue
                            onPhysicalAddressChange(updatedAddress)
                        }
                    ),
                    placeholder: "Apt, suite, unit, building, floor, etc.",
                    isLoading: isDisabled
                )
            }
        }
    }
}
