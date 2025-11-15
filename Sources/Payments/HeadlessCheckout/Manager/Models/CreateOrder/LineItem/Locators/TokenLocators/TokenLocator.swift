import CrossmintCommonTypes
import Foundation

// MARK: - Constants

private let genericInvalidTokenLocatorErrorMessage =
    "Invalid token locator. Expected: 'solana:<mintHash>' | '<blockchain>:<contractAddress>:<tokenId>'"

// MARK: - Token Locator

public enum TokenLocator: Codable, Sendable, CustomStringConvertible {
    case solana(SolanaTokenLocator)
    case evm(EvmTokenLocator)

    private static let initializers: [(@Sendable (String) -> TokenLocator?)] = [
        { try? .solana(SolanaTokenLocator.init(string: $0)) },
        { try? .evm(EvmTokenLocator.init(string: $0)) }
    ]

    public init(string value: String) throws(TokenLocatorError) {
        let tokenLocator: TokenLocator? = TokenLocator.initializers.reduce(nil) {
            result, initializer in
            guard result == nil else { return result }
            return initializer(value)
        }

        guard let locator = tokenLocator else {
            throw TokenLocatorError.invalidTokenLocator(genericInvalidTokenLocatorErrorMessage)
        }
        self = locator
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        self = try TokenLocator(string: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public var description: String {
        switch self {
        case .solana(let locator):
            return locator.description
        case .evm(let locator):
            return locator.description
        }
    }
}
