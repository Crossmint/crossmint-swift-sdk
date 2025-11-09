import Payments
import SwiftUI

// TODO: Implement
struct ExpressPaymentMethodContentView: View {
    private let paymentMethod: EmbeddedCheckoutLocalExpressPaymentMethod

    public init(_ paymentMethod: EmbeddedCheckoutLocalExpressPaymentMethod) {
        self.paymentMethod = paymentMethod
    }

    public var body: some View {
        EmptyView()
    }
}
