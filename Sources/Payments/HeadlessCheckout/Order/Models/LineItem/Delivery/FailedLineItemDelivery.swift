import Foundation

public struct FailedLineItemDeliveryReason: Codable, Sendable {
    public var code: FailureCode

    public enum FailureCode: String, Codable, Sendable {
        case slippageToleranceExceeded = "slippage-tolerance-exceeded"
    }
}

public struct FailedLineItemDelivery: Codable, Sendable {
    public var status: LineItemDeliveryStatus
    public var recipient: LineItemDeliveryRecipient?
    public var failureReason: FailedLineItemDeliveryReason?
}
