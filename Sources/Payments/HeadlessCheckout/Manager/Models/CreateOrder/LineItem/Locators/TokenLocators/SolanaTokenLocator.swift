import CrossmintCommonTypes
import Utils

public struct SolanaTokenLocator: Codable, Sendable, CustomStringConvertible {
    public private(set) var chain: Chain = .solana
    public let mintHash: SolanaAddress

    public var description: String {
        return "\(chain.name):\(mintHash.address)"
    }

    public init(mintHash: SolanaAddress) {
        self.mintHash = mintHash
    }

    public init(string value: String) throws(TokenLocatorError) {
        if isEmpty(value) {
            throw TokenLocatorError.invalidTokenLocator("Token locator string cannot be empty")
        }

        let parts = value.split(separator: ":")
        if parts.count != 2 {
            throw TokenLocatorError.invalidTokenLocator(
                "Solana token locator must have format 'solana:<mintHash>'")
        }

        if parts[0] != "solana" {
            throw TokenLocatorError.invalidTokenLocator(
                "Solana token locator must start with 'solana:'")
        }

        do {
            self.mintHash = try SolanaAddress(address: String(parts[1]))
        } catch {
            throw TokenLocatorError.invalidTokenLocator(
                "Invalid Solana mint hash format: \(parts[1])")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
