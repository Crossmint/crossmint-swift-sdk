public protocol CommonLineItemDeliveryToken: Codable, Sendable {
    var locator: TokenLocator { get set }
}
