import Foundation

public enum TokenLocatorError: Error, LocalizedError {
    case invalidTokenLocator(String)

    public var errorDescription: String? {
        switch self {
        case .invalidTokenLocator(let message):
            return message
        }
    }
}
