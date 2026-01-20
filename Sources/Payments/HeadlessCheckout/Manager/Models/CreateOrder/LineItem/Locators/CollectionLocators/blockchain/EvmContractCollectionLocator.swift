import CrossmintCommonTypes
import Utils

// MARK: - Constants

private let invalidBlockchainCollectionLocatorErrorMessage =
    "Invalid blockchain collection locator. " +
    "Expected: '<chain>:<contractAddress>' where chain is an EVM chain and contractAddress is a valid EVM address."

// MARK: - EvmContractCollectionLocator

public struct EvmContractCollectionLocator: Codable, Sendable, CustomStringConvertible {
    public let chain: EVMChain
    public let contractAddress: EVMAddress

    /// Initialize an EvmContractCollectionLocator from a string in the format "<chain>:0x<contractAddress>"
    /// - Parameter locator: The locator string to parse
    /// - Throws: CollectionLocatorError if the locator string is invalid
    public init(locator: String) throws(CollectionLocatorError) {
        guard !isEmpty(locator) else {
            throw CollectionLocatorError.invalidCollectionLocator(
                invalidBlockchainCollectionLocatorErrorMessage)
        }

        let parts = locator.split(separator: ":")

        guard parts.count == 2 else {
            throw CollectionLocatorError.invalidCollectionLocator(
                invalidBlockchainCollectionLocatorErrorMessage)
        }

        guard let chain = EVMChain(String(parts[0])) else {
            throw CollectionLocatorError.invalidCollectionLocator(invalidBlockchainCollectionLocatorErrorMessage)
        }
        self.chain = chain

        let contractAddress = String(parts[1])
        do {
            self.contractAddress = try EVMAddress(address: contractAddress)
        } catch {
            throw CollectionLocatorError.invalidCollectionLocator(
                invalidBlockchainCollectionLocatorErrorMessage)
        }
    }

    public var description: String {
        return "\(chain.name):\(contractAddress)"
    }
}
