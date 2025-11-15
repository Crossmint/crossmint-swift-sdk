import Combine
import SwiftUI
import Utils

@MainActor
public final class EmbeddedCheckoutStateManager: @unchecked Sendable, CheckoutStateManager {
    @Published public var paymentMethod: EmbeddedCheckoutLocalPaymentMethod = .card
    @Published public var isEditingDestination: Bool = false

    @Published public var destinationState: EmbeddedCheckoutLocalInputState =
        EmbeddedCheckoutLocalInputState(value: "", errorMessage: nil)
    @Published public var debouncedDestinationState: EmbeddedCheckoutLocalInputState =
        EmbeddedCheckoutLocalInputState(value: "", errorMessage: nil)

    private(set) lazy var destinationStateDebouncer:
        DebouncerViewModel<EmbeddedCheckoutLocalInputState> = {
            DebouncerViewModel(
                sourcePublisher: $destinationState.eraseToAnyPublisher(),
                destinationBinding: { [weak self] newValue in
                    self?.debouncedDestinationState = newValue
                },
                initialValue: destinationState,
                delay: 0.85)
        }()

    @Published public var receiptEmailState: EmbeddedCheckoutLocalInputState =
        EmbeddedCheckoutLocalInputState(value: "", errorMessage: nil)

    @Published public var globalMessage: EmbeddedCheckoutGlobalMessage?
    @Published public var submitInProgress: Bool = false
    @Published public var paymentChargedWaitingCallback: Bool = false
    @Published public var paymentModality: HeadlessCheckoutPaymentModality = .oneOff

    private var cancellables = Set<AnyCancellable>()

    public init(paymentMethod: EmbeddedCheckoutLocalPaymentMethod, receiptEmail: String?) {
        self.paymentMethod = paymentMethod
        self.receiptEmailState = EmbeddedCheckoutLocalInputState(
            value: receiptEmail ?? "", errorMessage: nil)

        // Access the lazy property to initialize it
        _ = destinationStateDebouncer
    }
}
