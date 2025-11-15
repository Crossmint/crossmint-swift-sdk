import CrossmintService
import Foundation
import Http

final class HeadlessOrderService: Sendable {
    private let crossmintService: CrossmintService

    private let errorHandler: @Sendable (NetworkError) -> OrderError? = { error in
        OrderError.networkError(error.localizedDescription)
    }

    init(crossmintService: CrossmintService) {
        self.crossmintService = crossmintService
    }

    private func execute<T: Decodable>(_ orderEndpoint: HeadlessCheckoutOrderEndpoint)
        async throws(OrderError) -> T {
        return try await self.crossmintService.executeRequest(
            orderEndpoint.endpoint,
            errorType: OrderError.self,
            self.errorHandler
        )
    }

    func fetchOrder(orderId: String, authHeaders: [String: String] = [:]) async throws(OrderError)
        -> Order {
        let endpoint = HeadlessCheckoutOrderEndpoint.getOrder(
            orderId: orderId, headers: authHeaders)
        return try await self.execute(endpoint)
    }

    func createOrder(input: HeadlessCheckoutCreateOrderInput, authHeaders: [String: String] = [:])
        async throws(OrderError) -> HeadlessCheckoutCreateOrderResponse {
        let endpoint = HeadlessCheckoutOrderEndpoint.createOrder(input: input, headers: authHeaders)
        return try await self.execute(endpoint)
    }

    func updateOrder(
        orderId: String, input: HeadlessCheckoutUpdateOrderInput,
        authHeaders: [String: String] = [:]
    )
        async throws(OrderError) -> Order {
        let endpoint = HeadlessCheckoutOrderEndpoint.updateOrder(
            orderId: orderId, input: input, headers: authHeaders)
        return try await self.execute(endpoint)
    }

    func processCryptoPayment(orderId: String, txId: String, authHeaders: [String: String] = [:])
        async throws(OrderError) -> Order {
        let endpoint = HeadlessCheckoutOrderEndpoint.processCryptoPayment(
            orderId: orderId, txId: txId, headers: authHeaders
        )
        return try await self.execute(endpoint)
    }

    func refreshOrder(orderId: String, authHeaders: [String: String] = [:])
        async throws(OrderError) -> Order {
        let endpoint = HeadlessCheckoutOrderEndpoint.refreshOrder(
            orderId: orderId, headers: authHeaders)
        return try await self.execute(endpoint)
    }
}
