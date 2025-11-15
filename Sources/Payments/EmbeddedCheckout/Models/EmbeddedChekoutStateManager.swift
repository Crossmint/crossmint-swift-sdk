import Foundation

@MainActor
public protocol CheckoutStateManager: ObservableObject {
    var paymentMethod: EmbeddedCheckoutLocalPaymentMethod { get set }
    var isEditingDestination: Bool { get set }

    var debouncedDestinationState: EmbeddedCheckoutLocalInputState { get }
    var destinationState: EmbeddedCheckoutLocalInputState { get set }

    var receiptEmailState: EmbeddedCheckoutLocalInputState { get set }
    var globalMessage: EmbeddedCheckoutGlobalMessage? { get set }
    var submitInProgress: Bool { get set }

    var paymentModality: HeadlessCheckoutPaymentModality { get set }
}
