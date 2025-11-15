import Payments
import SwiftUI

// TODO implement
struct EmbeddedCheckoutPhysicalAddressNameInput: View {
    let name: String
    let onChange: (String) -> Void
    // TODO use appearance manager
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @EnvironmentObject var checkoutStateManager: EmbeddedCheckoutStateManager

    var isDisabled: Bool {
        self.orderManager.isUpdatingOrder || self.orderManager.isPolling
            || self.checkoutStateManager.submitInProgress
    }

    init(name: String, onChange: @escaping (String) -> Void) {
        self.name = name
        self.onChange = onChange
    }

    var body: some View {
        EmbeddedCheckoutInput(
            text: Binding(
                get: { self.name },
                set: { self.onChange($0) }
            ),
            placeholder: "Full name",
            isLoading: isDisabled,
            keyboardType: .default,
            contentType: .name
        )
        .padding(.bottom, 24)
    }
}
