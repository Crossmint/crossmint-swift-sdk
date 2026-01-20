import Combine
import Payments
import SwiftUI
import Utils
import Logger

// TODO implement
struct EmbeddedCheckoutPhysicalAddressForm: View {
    @EnvironmentObject var orderManager: HeadlessCheckoutOrderManager
    @StateObject private var nameDebouncer: DebouncerViewModel<String>
    @StateObject private var addressWithoutNameDebouncer: DebouncerViewModel<PhysicalAddressWithoutName?>

    private var cancellables = Set<AnyCancellable>()

    init(defaultAddress: PhysicalAddress? = nil) {
        let name = defaultAddress?.name
        let physicalAddressWithoutName = defaultAddress?.withoutName()

        self._nameDebouncer = StateObject(
            wrappedValue: DebouncerViewModel<String>(initialValue: name ?? "", delay: 1)
        )
        self._addressWithoutNameDebouncer = StateObject(
            wrappedValue: DebouncerViewModel<PhysicalAddressWithoutName?>(
                initialValue: physicalAddressWithoutName, delay: 1
            )
        )
    }

    var body: some View {
        EmptyView()
    }

    private func updateOrderIfNeeded() {
        // TODO implement
    }

    private func isAddressComplete(_ address: PhysicalAddressWithoutName) -> Bool {
        return !address.line1.isEmpty && !address.city.isEmpty && !address.state.isEmpty
            && !address.postalCode.isEmpty && !address.country.isEmpty
    }
}
