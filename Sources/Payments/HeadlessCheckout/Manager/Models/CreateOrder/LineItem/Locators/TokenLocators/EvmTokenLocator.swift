import CrossmintCommonTypes
import Utils

public struct EvmTokenLocator: Codable, Sendable, CustomStringConvertible {
    public let chain: EVMChain
    public let contractAddress: EVMAddress
    public let tokenId: String

    public var description: String {
        return "\(chain.name):\(contractAddress.address):\(tokenId)"
    }

    public init(chain: EVMChain, contractAddress: EVMAddress, tokenId: String) {
        self.chain = chain
        self.contractAddress = contractAddress
        self.tokenId = tokenId
    }

    // Throwing initializer from string
    public init(string value: String) throws(TokenLocatorError) {
        if isEmpty(value) {
            throw TokenLocatorError.invalidTokenLocator("Token locator string cannot be empty")
        }

        let parts = value.split(separator: ":")
        if parts.count != 3 {
            throw TokenLocatorError.invalidTokenLocator(
                "EVM token locator must have format '<chain>:<contractAddress>:<tokenId>'")
        }

        // Validate chain
        let chainName = String(parts[0])

        // Use the convenience initializer from EVMBlockchain
        guard let chain = EVMChain(chainName) else {
            throw TokenLocatorError.invalidTokenLocator(
                "Chain '\(chainName)' is not a supported EVM chain")
        }

        self.chain = chain

        // Validate EVM address format
        do {
            self.contractAddress = try EVMAddress(address: String(parts[1]))
        } catch {
            throw TokenLocatorError.invalidTokenLocator(
                "Invalid EVM contract address format: \(parts[1])")
        }

        // Validate tokenId is a number
        if Int(parts[2]) == nil {
            throw TokenLocatorError.invalidTokenLocator(
                "Token ID must be a valid integer: \(parts[2])")
        }

        self.tokenId = String(parts[2])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
