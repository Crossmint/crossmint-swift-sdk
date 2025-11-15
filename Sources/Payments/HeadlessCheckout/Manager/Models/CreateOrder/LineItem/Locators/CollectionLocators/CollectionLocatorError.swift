import Foundation

public enum CollectionLocatorError: Error, LocalizedError {
    case invalidCollectionLocator(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCollectionLocator(let message):
            return message
        }
    }
}
