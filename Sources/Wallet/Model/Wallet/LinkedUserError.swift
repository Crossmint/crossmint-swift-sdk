import Foundation

public enum LinkedUserError: Error, LocalizedError {
    case invalidLocator(String)
    case unknownType(String)

    public var errorDescription: String? {
        switch self {
        case .invalidLocator(let locator):
            return "Invalid user locator: \(locator). Expected format: type:value"
        case .unknownType(let type): return "Unknown user type: \(type)"
        }
    }
}
