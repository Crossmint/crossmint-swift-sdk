import CrossmintService
import Http

public enum CheckoutComEndpoint {
    case submitPayment(
        checkoutComPaymentInput: CheckoutComPaymentInput, headers: [String: String] = [:])

    var endpoint: Endpoint {
        let encoder = DefaultJSONCoder()

        switch self {
        case .submitPayment(let checkoutComPaymentInput, let headers):
            return Endpoint(
                path: "/payments",
                method: .post,
                headers: headers,
                body: try? encoder.encode(checkoutComPaymentInput)
            )
        }
    }
}
