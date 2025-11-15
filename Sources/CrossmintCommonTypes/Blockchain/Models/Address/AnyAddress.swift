public protocol BlockchainAddress: Codable, Sendable, Equatable, Hashable, CustomStringConvertible {
    init(address: String) throws(BlockchainAddressError)
}
