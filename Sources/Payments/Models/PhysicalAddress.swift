public struct PhysicalAddressWithoutName: Codable, Equatable, Sendable {
    public var line1: String
    public var line2: String?
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String
}

public struct PhysicalAddress: Codable, Equatable, Sendable {
    public var name: String
    public var line1: String
    public var line2: String?
    public var city: String
    public var state: String
    public var postalCode: String
    public var country: String
}

extension PhysicalAddress {
    public func withoutName() -> PhysicalAddressWithoutName {
        return .init(
            line1: self.line1,
            line2: self.line2,
            city: self.city,
            state: self.state,
            postalCode: self.postalCode,
            country: self.country
        )
    }
}
