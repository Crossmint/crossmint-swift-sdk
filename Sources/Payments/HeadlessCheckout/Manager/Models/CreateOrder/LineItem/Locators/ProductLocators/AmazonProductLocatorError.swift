import Foundation

public enum AmazonProductLocatorError: Error, LocalizedError {
    case emptyLocator
    case invalidPrefix(expected: String, got: String)
    case missingAsinOrUrl
    case invalidAmazonUrlOrAsin(String)

    public var errorDescription: String? {
        switch self {
        case .emptyLocator:
            return "Product locator cannot be empty"
        case .invalidPrefix(let expected, let got):
            return "Invalid platform prefix. Expected '\(expected)', got '\(got)'"
        case .missingAsinOrUrl:
            return "URL or ASIN is required after the 'amazon:' prefix"
        case .invalidAmazonUrlOrAsin(let value):
            return "Invalid Amazon URL or ASIN: \(value)"
        }
    }
}
