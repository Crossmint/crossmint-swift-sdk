import Foundation

public enum CreateOrderLineItemError: Error, LocalizedError {
    case invalidLineItem(String)
    case allItemsNotOfSameType
    case includeAtLeastOneLineItem
    case tokenBaseLayerMismatch
    case collectionLocatorsNotEqual

    public var errorDescription: String? {
        switch self {
        case .invalidLineItem(let message):
            return message
        case .allItemsNotOfSameType:
            return
                "All line items must be of the same type. Please include either 'collectionLocator' or "
                + "'tokenLocator' or 'productLocator' in all items"
        case .tokenBaseLayerMismatch:
            return "All token items must have the same base layer locator"
        case .includeAtLeastOneLineItem:
            return "Please include at least one line item"
        case .collectionLocatorsNotEqual:
            return "All collection items must have the same locator"
        }
    }
}
