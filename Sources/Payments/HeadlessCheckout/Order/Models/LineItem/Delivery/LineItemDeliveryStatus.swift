public enum NotFinishedLineItemDeliveryStatus: String, Codable, Sendable {
    case awaitingPayment = "awaiting-payment"
    case inProgress = "in-progress"
    case failed = "failed"
}

public enum LineItemDeliveryStatus: String, Codable, Sendable {
    // Delivered status
    case completed = "completed"

    // Not finished statuses
    case failed = "failed"
    case awaitingPayment = "awaiting-payment"
    case inProgress = "in-progress"
}

extension LineItemDeliveryStatus {
    public var isDelivered: Bool {
        self == .completed
    }

    public var isFailed: Bool {
        self == .failed
    }

    public var isNotFinished: Bool {
        switch self {
        case .awaitingPayment, .inProgress, .failed:
            return true
        case .completed:
            return false
        }
    }
}
