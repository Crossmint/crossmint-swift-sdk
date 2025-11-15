import Foundation

public enum LineItemDelivery: Codable, Sendable {
    case notFinished(NotFinishedLineItemDelivery)
    case failed(FailedLineItemDelivery)
    case delivered(DeliveredLineItemDelivery)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let status = try container.decode(LineItemDeliveryStatus.self, forKey: .status)

        switch status {
        case .completed:
            let delivered = try DeliveredLineItemDelivery(from: decoder)
            self = .delivered(delivered)
        case .failed:
            let failed = try FailedLineItemDelivery(from: decoder)
            self = .failed(failed)
        case .awaitingPayment, .inProgress:
            let notFinished = try NotFinishedLineItemDelivery(from: decoder)
            self = .notFinished(notFinished)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .notFinished(let notFinished):
            try notFinished.encode(to: encoder)
        case .failed(let failed):
            try failed.encode(to: encoder)
        case .delivered(let delivered):
            try delivered.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
    }

    public var notFinished: NotFinishedLineItemDelivery? {
        if case .notFinished(let delivery) = self {
            return delivery
        }

        return nil
    }

    public var failed: FailedLineItemDelivery? {
        if case .failed(let delivery) = self {
            return delivery
        }

        return nil
    }

    public var delivered: DeliveredLineItemDelivery? {
        if case .delivered(let delivery) = self {
            return delivery
        }

        return nil
    }
}

public struct NotFinishedLineItemDelivery: Codable, Sendable {
    public var status: NotFinishedLineItemDeliveryStatus
    public var recipient: LineItemDeliveryRecipient?
}

extension LineItemDelivery {
    public var recipient: LineItemDeliveryRecipient? {
        switch self {
        case .notFinished(let delivery): return delivery.recipient
        case .failed(let delivery): return delivery.recipient
        case .delivered(let delivery): return delivery.recipient
        }
    }
}
