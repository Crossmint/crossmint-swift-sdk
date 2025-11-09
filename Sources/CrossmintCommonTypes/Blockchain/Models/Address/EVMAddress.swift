import Foundation

public struct EVMAddress: BlockchainAddress {
    public private(set) var address: String

    public init(address: String) throws(BlockchainAddressError) {
        guard address.range(of: "^0x[0-9a-fA-F]{40}$", options: .regularExpression) != nil else {
            throw BlockchainAddressError.invalidEVMAddress("Invalid EVM address format: \(address)")
        }
        self.address = address
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address)
    }

    public var description: String {
        address
    }
}
