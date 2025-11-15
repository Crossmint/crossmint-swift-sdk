import Foundation

public struct Metadata: Codable, Sendable {
    public var name: String
    public var description: String
    public var imageUrl: URL
}

public struct DeepOptionalMetadata: Codable, Sendable {
    public var name: String?
    public var description: String?
    public var imageUrl: URL?
}

public struct MetadataWithOptionalCollection: Codable, Sendable {
    public var name: String
    public var description: String
    public var imageUrl: URL
    public var collection: DeepOptionalMetadata?
}
