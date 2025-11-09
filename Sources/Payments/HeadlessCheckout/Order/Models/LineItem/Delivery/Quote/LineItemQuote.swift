public protocol BaseLineItemQuote: Codable, Sendable {
    var status: LineItemQuoteStatus { get set }
    var unavailabilityReason: LineItemQuoteUnavailabilityReason? { get set }
    var charges: LineItemPricingCharges? { get set }
    var totalPrice: Price? { get set }
}

public struct ExactOutLineItemQuote: BaseLineItemQuote {
    public var status: LineItemQuoteStatus
    public var unavailabilityReason: LineItemQuoteUnavailabilityReason?
    public var charges: LineItemPricingCharges?
    public var totalPrice: Price?

}

public struct QualityRange: Codable, Sendable {
    public var lowerBound: String
    public var upperBound: String
}
public struct ExactInLineItemQuote: BaseLineItemQuote {
    public var status: LineItemQuoteStatus
    public var unavailabilityReason: LineItemQuoteUnavailabilityReason?
    public var charges: LineItemPricingCharges?
    public var totalPrice: Price?
    public var qualityRange: QualityRange
}

public enum LineItemQuote: Codable, Sendable {
    case exactOut(ExactOutLineItemQuote)
    case exactIn(ExactInLineItemQuote)

    var isUnavailable: Bool {
        switch self {
        case .exactOut(let quote):
            return quote.status == .itemUnavailable
        case .exactIn(let quote):
            return quote.status == .itemUnavailable
        }
    }

    var unavailabilityReason: LineItemQuoteUnavailabilityReason? {
        switch self {
        case .exactOut(let quote):
            return quote.unavailabilityReason
        case .exactIn(let quote):
            return quote.unavailabilityReason
        }
    }

    // Custom Codable implementation to handle LineItemQuote without a top-level key
    public init(from decoder: Decoder) throws {
        // First, try to decode as a single value container (for direct BaseLineItemQuote properties)
        let container = try decoder.singleValueContainer()

        // Try to decode as ExactOutLineItemQuote first
        do {
            let exactOutQuote = try container.decode(ExactOutLineItemQuote.self)
            self = .exactOut(exactOutQuote)
            return
        } catch {
            // If that fails, try ExactInLineItemQuote
            do {
                let exactInQuote = try container.decode(ExactInLineItemQuote.self)
                self = .exactIn(exactInQuote)
                return
            } catch {
                // If both fail, throw an error
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription:
                        "Cannot decode LineItemQuote: neither ExactOutLineItemQuote nor ExactInLineItemQuote could be decoded"
                )
            }
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .exactOut(let exactOutQuote):
            try exactOutQuote.encode(to: encoder)
        case .exactIn(let exactInQuote):
            try exactInQuote.encode(to: encoder)
        }
    }

    public var charges: LineItemPricingCharges? {
        switch self {
        case .exactOut(let quote):
            return quote.charges
        case .exactIn(let quote):
            return quote.charges
        }
    }

    public var totalPrice: Price? {
        switch self {
        case .exactOut(let quote):
            return quote.totalPrice
        case .exactIn(let quote):
            return quote.totalPrice
        }
    }
}
