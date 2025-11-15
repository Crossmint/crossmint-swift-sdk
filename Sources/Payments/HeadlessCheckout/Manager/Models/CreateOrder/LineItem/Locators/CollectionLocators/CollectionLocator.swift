// TODO implementaion

public enum CollectionLocator: Codable, Sendable, CustomStringConvertible {
    case crossmintCollection(CrossmintCollectionLocator)
    case blockchainCollection(BlockchainCollectionLocator)

    public init(locator: String) throws(CollectionLocatorError) {
        do {
            self = .crossmintCollection(try CrossmintCollectionLocator(locator: locator))
        } catch {
            do {
                self = .blockchainCollection(try BlockchainCollectionLocator(locator: locator))
            } catch {
                throw CollectionLocatorError.invalidCollectionLocator(
                    // swiftlint:disable:next line_length
                    "Invalid collection locator. Expected: '<chain>:<contractAddress>' or 'crossmint:<collectionId>' or 'crossmint:<collectionId>:<templateId>'"
                )
            }
        }
    }

    public var description: String {
        switch self {
        case .crossmintCollection(let locator):
            return locator.description
        case .blockchainCollection(let locator):
            return locator.description
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .crossmintCollection(let locator): try container.encode(locator)
        case .blockchainCollection(let locator): try container.encode(locator)
        }
    }
}
