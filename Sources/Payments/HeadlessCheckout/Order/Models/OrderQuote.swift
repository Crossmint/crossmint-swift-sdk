import Foundation

public struct OrderQuote: Codable, Sendable {
    public var status: OrderQuoteStatus
    public var quotedAt: Date?
    public var expiresAt: Date?
    public var totalPrice: Price?
}
