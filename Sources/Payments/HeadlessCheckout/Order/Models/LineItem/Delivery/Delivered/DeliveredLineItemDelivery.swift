import Foundation

public struct DeliveredLineItemDelivery: Codable, Sendable {
    public var status: LineItemDeliveryStatus
    public var recipient: LineItemDeliveryRecipient?
    public var txId: String
    public var tokens: [LineItemDeliveryToken]
}
