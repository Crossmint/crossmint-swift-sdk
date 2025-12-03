public enum ResponseStatus: String, Codable, Sendable {
    case success
    case error
}

public struct PublicKey: Codable, Equatable, Sendable {
    public let bytes: String
    public let encoding: String
    public let keyType: String
}

public struct PublicKeys: Codable, Equatable, Sendable {
    public let ed25519: PublicKey
    public let secp256k1: PublicKey
}
