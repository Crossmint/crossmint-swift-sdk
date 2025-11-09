public struct HeadlessCheckoutCreateOrderResponse: Decodable, Sendable {
    public let order: Order
    public let clientSecret: String
}
