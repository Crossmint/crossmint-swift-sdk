public protocol SpecificChain: AnyChain, Equatable, Sendable, Hashable, Codable {
    var chain: Chain { get }

    init?(_ from: String)
}
