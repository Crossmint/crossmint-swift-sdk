import Foundation

public enum ProductLocatorError: Error, LocalizedError {
    case invalidProductLocator
    case invalidAmazonProductLocator(AmazonProductLocatorError)

    public var errorDescription: String? {
        switch self {
        case .invalidProductLocator:
            return "Invalid product locator. Expected: 'amazon:<url>' | 'amazon:<asin>'"
        case .invalidAmazonProductLocator(let error):
            return "Invalid Amazon product locator: \(error.localizedDescription)"
        }
    }
}
