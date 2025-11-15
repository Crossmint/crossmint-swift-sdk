import Foundation

public struct WithCollectionLocator: Codable, Sendable {
    public var collectionLocator: CollectionLocator
    public var callData: CallData?

    public init(collectionLocator: CollectionLocator, callData: CallData?) {
        self.collectionLocator = collectionLocator
        self.callData = callData
    }
}

public struct WithTokenLocator: Codable, Sendable {
    public var tokenLocator: TokenLocator
    public var callData: CallData?
    public var executionParameters: ExecutionParameters?

    public init(
        tokenLocator: TokenLocator, callData: CallData?, executionParameters: ExecutionParameters?
    ) {
        self.tokenLocator = tokenLocator
        self.callData = callData
        self.executionParameters = executionParameters
    }
}

public struct WithProductLocator: Codable, Sendable {
    public var productLocator: ProductLocator
    public var callData: CallData?
}

public enum CreateOrderParsedLineItem: Codable, Sendable {
    case withCollectionLocator(WithCollectionLocator)
    case withTokenLocator(WithTokenLocator)
    case withProductLocator(WithProductLocator)

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .withCollectionLocator(let collectionLocator): try container.encode(collectionLocator)
        case .withTokenLocator(let tokenLocator): try container.encode(tokenLocator)
        case .withProductLocator(let productLocator): try container.encode(productLocator)
        }
    }
}

public struct CreateOrderLineItems: Codable, Sendable {
    public var items: [CreateOrderParsedLineItem]

    public init(items: [CreateOrderParsedLineItem]) throws(CreateOrderLineItemError) {
        if items.isEmpty {
            throw CreateOrderLineItemError.includeAtLeastOneLineItem
        }
        self.items = items

        try validateSameType(items: items)
        try validateLocatorType(items: items)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        // Try to decode as an array first
        do {
            let lineItems = try container.decode([CreateOrderParsedLineItem].self)
            try self.init(items: lineItems)
        } catch {
            // If array decoding fails, try to decode as a single object
            do {
                let singleItem: CreateOrderParsedLineItem = try container.decode(
                    CreateOrderParsedLineItem.self)
                try self.init(items: [singleItem])
            } catch let decodingError {
                // If both attempts fail, throw the decoding error
                throw decodingError
            }
        }
    }

    private func validateSameType(items: [CreateOrderParsedLineItem])
        throws(CreateOrderLineItemError) {
        guard !items.isEmpty else { return }

        let firstItem: CreateOrderParsedLineItem = items[0]
        let allSameType: Bool = items.allSatisfy { item in
            switch (firstItem, item) {
            case (.withCollectionLocator, .withCollectionLocator),
                (.withTokenLocator, .withTokenLocator),
                (.withProductLocator, .withProductLocator):
                return true
            default:
                return false
            }
        }

        if !allSameType {
            throw CreateOrderLineItemError.allItemsNotOfSameType
        }
    }

    private func validateLocatorType(items: [CreateOrderParsedLineItem])
        throws(CreateOrderLineItemError) {
        let firstItem: CreateOrderParsedLineItem = items[0]

        switch firstItem {
        case .withCollectionLocator:
            try validateCollectionLocatorsEqual(
                items.compactMap {
                    if case let .withCollectionLocator(item) = $0 {
                        return item.collectionLocator
                    }
                    return nil
                })
        case .withTokenLocator:
            try validateTokenLocatorsFromSameBaseLayer(
                items.compactMap {
                    if case let .withTokenLocator(item) = $0 {
                        return item.tokenLocator
                    }
                    return nil
                })
        default:
            break
        }
    }

    private func validateCollectionLocatorsEqual(_ locators: [CollectionLocator])
        throws(CreateOrderLineItemError) {
        guard !locators.isEmpty else { return }

        let first = locators[0]

        // Check if all locators have the same description (string representation)
        let allEqual = locators.allSatisfy { $0.description == first.description }

        if !allEqual {
            throw CreateOrderLineItemError.collectionLocatorsNotEqual
        }
    }

    private func validateTokenLocatorsFromSameBaseLayer(_ locators: [TokenLocator])
        throws(CreateOrderLineItemError) {
        guard !locators.isEmpty else { return }

        let first = locators[0]

        // Check if all token locators start with the first token locator string
        let firstString = first.description
        let allFromSameBase = locators.allSatisfy {
            let currentString = $0.description
            return currentString.hasPrefix(firstString)
        }

        if !allFromSameBase {
            throw CreateOrderLineItemError.tokenBaseLayerMismatch
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(items)
    }
}
