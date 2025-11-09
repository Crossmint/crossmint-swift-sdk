import Foundation

public enum CheckoutComPaymentStatus: String, Codable {
    case authorized = "Authorized"
    case pending = "Pending"
    case cardVerified = "Card Verified"
    case declined = "Declined"
    case retryScheduled = "Retry Scheduled"
}

public struct CheckoutComPaymentResponseLinks: Codable {
    public let `self`: CheckoutComPaymentResponseLink
    public let actions: CheckoutComPaymentResponseLink
}

public struct CheckoutComPaymentResponseLink: Codable {
    public let href: String
}

public struct CheckoutComPaymentResponse: Codable {
    public let id: String
    public let actionId: String  // action_id
    public let amount: Int
    public let currency: String
    public let approved: Bool
    public let status: CheckoutComPaymentStatus
    public let responseCode: String  // response_code
    public let processedOn: Date  // processed_on
    public let links: CheckoutComPaymentResponseLinks

    enum CodingKeys: String, CodingKey {
        case id
        case actionId = "action_id"
        case amount
        case currency
        case approved
        case status
        case responseCode = "response_code"
        case processedOn = "processed_on"
        case links = "_links"
    }
}
