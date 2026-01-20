import Http
import Logger

#if canImport(CheckoutComponents)
    import CheckoutComponents
#elseif canImport(CheckoutComponentsSDK)
    import CheckoutComponentsSDK
#endif

final class CheckoutComAdapter: Sendable {

    /**
    HEADERS:
      -H 'Authorization: Bearer <YOUR_TOKEN_HERE>' probably (paymentSessionSecret)
      -H 'Cko-Idempotency-Key: string' (order.id)
      -H 'Content-Type: application/json'

    Example request:
    {
        "source": {
            "type": "token",
            "token": "tok_4gzeau5o2uqubbk6fufs3m7p54"
        },
        "amount": 6500,
        "currency": "USD",
        "processing_channel_id": "pc_ovo75iz4hdyudnx6tu74mum3fq",
        "reference": "ORD-5023-4E89",
        "metadata": {
            "udf1": "TEST123",
            "coupon_code": "NY2024",
            "partner_id": 123989
        }
    }
    */
    private let checkoutComService: CheckoutComService
    private let errorHandler: @Sendable (NetworkError) -> CheckoutComError? = { error in
        CheckoutComError.fromNetworkError(error)
    }

    public init() {
        // TODO use environment variable
        self.checkoutComService = CheckoutComService(productionEnvironment: false)
    }

    private func execute<T: Decodable>(_ endpoint: CheckoutComEndpoint)
        async throws(CheckoutComError) -> T {
        return try await self.checkoutComService.executeRequest(
            endpoint.endpoint, self.errorHandler)
    }

    public func submitPayment(
        withToken tokenDetails: CheckoutComponents.TokenizationResult,
        forOrder order: Order
    ) async throws(CheckoutComError) -> CheckoutComPaymentResponse {
        guard
            case let .preparation(preparation) = order.payment.paymentStage,
            case let .checkoutcomOrderPaymentPreparation(checkoutComPreparation) = preparation,
            let paymentSessionSecret = checkoutComPreparation.checkoutcomPaymentSession?
                .paymentSessionSecret
        else {
            Logger.payments.error(
                "[CheckoutComAdapter.submitPayment] Not a checkout.com order. Cannot retrieve payment session secret"
            )
            throw CheckoutComError.invalidOrderState(
                "Not a checkout.com order. Cannot retrieve payment session secret"
            )
        }

        let headers = [
            "Authorization": "Bearer \(paymentSessionSecret)",
            "Cko-Idempotency-Key": order.orderIdString
        ]

        Logger.payments.debug(
            "[CheckoutComAdapter.submitPayment] Headers: \(headers.json(prettyPrinted: true))"
        )

        let checkoutComPaymentInput = CheckoutComPaymentInput(
            source: .tokenSource(CheckoutComTokenSourceType(token: tokenDetails.data.token)),
            currency: order.payment.currency.name.uppercased()
        )

        Logger.payments.debug(
            "[CheckoutComAdapter.submitPayment] " +
            "CheckoutComPaymentInput: \(checkoutComPaymentInput.json(prettyPrinted: true))"
        )

        let endpoint = CheckoutComEndpoint.submitPayment(
            checkoutComPaymentInput: checkoutComPaymentInput, headers: headers)
        return try await self.execute(endpoint)
    }
}
