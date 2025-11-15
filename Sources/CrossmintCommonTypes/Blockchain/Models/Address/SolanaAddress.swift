import Foundation
import Utils

public struct SolanaAddress: BlockchainAddress {
    public private(set) var address: String
    public private(set) var publicKey: String

    public init(address: String) throws(BlockchainAddressError) {
        guard address.range(of: "^[1-9A-HJ-NP-Za-km-z]{32,44}$", options: .regularExpression) != nil
        else {
            throw BlockchainAddressError.invalidSolanaAddress(
                "Invalid Solana address format: \(address)")
        }
        self.address = address
        do {
            self.publicKey = try Base58.decode(address, padTo32: true).toHexString(withPrefix: false)
        } catch {
            throw BlockchainAddressError.invalidSolanaAddress("Public key cannot be derived from \(address)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address)
    }

    public var description: String {
        address
    }
}
