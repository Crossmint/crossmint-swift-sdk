import Foundation

public struct OrderItem: Identifiable, Codable {
    public var id: String
    public var name: String
    public var quantity: Int
    public var price: Decimal
    public var imageURL: URL?
}
