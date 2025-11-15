import Utils

// MARK: - Constants

private let genericInvalidTokenLocatorErrorMessage =
    "Invalid collection locator. Expected: 'crossmint:<collectionId>' or 'crossmint:<collectionId>:<templateId>'"

// MARK: - CrossmintCollectionLocator

/// The Crossmint collection locator of the line item.
/// Eg. 'crossmint:<collectionId>' or 'crossmint:<collectionId>:<templateId>'.
/// The collectionId field can be retrieved from the Crossmint console.
public struct CrossmintCollectionLocator: Codable, Sendable, CustomStringConvertible {
    public let collectionId: String
    public let templateId: String?

    /// Initialize a CrossmintCollectionLocator from a string in the format "crossmint:<collectionId>" or "crossmint:<collectionId>:<templateId>"
    /// - Parameter locator: The locator string to parse
    /// - Throws: CollectionLocatorError if the locator string is invalid
    public init(locator: String) throws(CollectionLocatorError) {
        guard !isEmpty(locator) else {
            throw CollectionLocatorError.invalidCollectionLocator(
                genericInvalidTokenLocatorErrorMessage)
        }

        let parts = locator.split(separator: ":")

        guard parts.count == 3 || parts.count == 2 else {
            throw CollectionLocatorError.invalidCollectionLocator(
                genericInvalidTokenLocatorErrorMessage)
        }

        guard parts[0] == "crossmint" else {
            throw CollectionLocatorError.invalidCollectionLocator(
                genericInvalidTokenLocatorErrorMessage)
        }

        self.collectionId = String(parts[1])
        self.templateId = parts.count == 3 ? String(parts[2]) : nil
    }

    public var description: String {
        if let templateId = templateId {
            return "crossmint:\(collectionId):\(templateId)"
        } else {
            return "crossmint:\(collectionId)"
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
