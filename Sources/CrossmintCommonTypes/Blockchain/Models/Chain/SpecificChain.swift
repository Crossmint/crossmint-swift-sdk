public protocol SpecificChain: AnyChain, Equatable, Sendable, Hashable, Codable {
    var chain: Chain { get }

    init?(_ from: String)
}

extension SpecificChain {
     public static func == (lhs: Chain, rhs: Self) -> Bool {
         lhs.name == rhs.name
     }

     public static func == (lhs: Self, rhs: Chain) -> Bool {
         lhs.name == rhs.name
     }

    public static func != (lhs: Chain, rhs: Self) -> Bool {
        !(lhs.name == rhs.name)
    }

    public static func != (lhs: Self, rhs: Chain) -> Bool {
        !(lhs.name == rhs.name)
    }
 }
