public protocol AnyChain: Sendable {
    var name: String { get }
    var chainType: ChainType { get }
    func isValid(isProductionEnvironment: Bool) -> Bool
}
