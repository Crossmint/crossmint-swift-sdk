public enum LineItemQuoteStatus: String, Codable, Sendable {
    case itemUnavailable = "item-unavailable"
    case valid
    case expired
    case requiresRecipient = "requires-recipient"
}
