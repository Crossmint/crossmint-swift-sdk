import CrossmintCommonTypes

public enum BlockchainCollectionLocator: Codable, Sendable, CustomStringConvertible {
    case evmContract(EvmContractCollectionLocator)

    public init(locator: String) throws(CollectionLocatorError) {
        do {
            self = .evmContract(try EvmContractCollectionLocator(locator: locator))
        } catch {
            throw CollectionLocatorError.invalidCollectionLocator(
                "Invalid blockchain collection locator. Expected: '<chain>:<contractAddress>'")
        }
    }

    public var description: String {
        switch self {
        case .evmContract(let locator):
            return locator.description
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
