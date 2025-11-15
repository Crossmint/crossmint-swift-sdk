public enum OrderQuoteStatus: String, Codable, Sendable {
    case requiresRecipient = "requires-recipient"
    case requiresPhysicalAddress = "requires-physical-address"
    case allLineItemsUnavailable = "all-line-items-unavailable"
    case valid = "valid"
    case expired = "expired"
}
