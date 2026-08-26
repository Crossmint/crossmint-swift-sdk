public enum CryptoCurrency: Codable, Sendable, Hashable, Comparable, RangeExpression, Equatable, CaseIterable {
    public static var allCases: [CryptoCurrency] {
        KnownCryptoCurrency.allCases.map(\.currency)
    }

    case ape
    case eth
    case matic
    case pol
    case sei
    case chz
    case avax
    case xai
    case fuel
    case vic
    case ip
    case usdc
    case usdce
    case busd
    case usdxm
    case weth
    case degen
    case brett
    case toshi
    case eurc
    case superverse
    case bonk
    case wif
    case mother
    case sol
    case xlm
    case ada
    case bnb
    case sui
    case apt
    case sfuel

    // Future-proof
    case unknown(String)

    public init(name: String) {
        self = KnownCryptoCurrency(rawValue: name).map(\.currency) ?? .unknown(name)
    }

    // Comparable requirement
    public static func < (lhs: CryptoCurrency, rhs: CryptoCurrency) -> Bool {
        return lhs.name < rhs.name
    }

    // RangeExpression requirements
    public func relative<C>(to collection: C) -> Range<CryptoCurrency>
    where C: Collection, CryptoCurrency == C.Index {
        return self..<self
    }

    public func contains(_ element: CryptoCurrency) -> Bool {
        return self == element
    }

    public func relative<C>(to collection: C) -> Range<C.Index> where C: Collection {
        let idx =
            collection.firstIndex(where: { ($0 as? CryptoCurrency) == self })
            ?? collection.startIndex
        return idx..<collection.index(after: idx)
    }

    public var name: String {
        return switch self {
        case .unknown(let name):
            name
        case .ape:
            KnownCryptoCurrency.ape.rawValue
        case .eth:
            KnownCryptoCurrency.eth.rawValue
        case .matic:
            KnownCryptoCurrency.matic.rawValue
        case .pol:
            KnownCryptoCurrency.pol.rawValue
        case .sei:
            KnownCryptoCurrency.sei.rawValue
        case .chz:
            KnownCryptoCurrency.chz.rawValue
        case .avax:
            KnownCryptoCurrency.avax.rawValue
        case .xai:
            KnownCryptoCurrency.xai.rawValue
        case .fuel:
            KnownCryptoCurrency.fuel.rawValue
        case .vic:
            KnownCryptoCurrency.vic.rawValue
        case .ip:
            KnownCryptoCurrency.ip.rawValue
        case .usdc:
            KnownCryptoCurrency.usdc.rawValue
        case .usdce:
            KnownCryptoCurrency.usdce.rawValue
        case .busd:
            KnownCryptoCurrency.busd.rawValue
        case .usdxm:
            KnownCryptoCurrency.usdxm.rawValue
        case .weth:
            KnownCryptoCurrency.weth.rawValue
        case .degen:
            KnownCryptoCurrency.degen.rawValue
        case .brett:
            KnownCryptoCurrency.brett.rawValue
        case .toshi:
            KnownCryptoCurrency.toshi.rawValue
        case .eurc:
            KnownCryptoCurrency.eurc.rawValue
        case .superverse:
            KnownCryptoCurrency.superverse.rawValue
        case .bonk:
            KnownCryptoCurrency.bonk.rawValue
        case .wif:
            KnownCryptoCurrency.wif.rawValue
        case .mother:
            KnownCryptoCurrency.mother.rawValue
        case .sol:
            KnownCryptoCurrency.sol.rawValue
        case .xlm:
            KnownCryptoCurrency.xlm.rawValue
        case .ada:
            KnownCryptoCurrency.ada.rawValue
        case .bnb:
            KnownCryptoCurrency.bnb.rawValue
        case .sui:
            KnownCryptoCurrency.sui.rawValue
        case .apt:
            KnownCryptoCurrency.apt.rawValue
        case .sfuel:
            KnownCryptoCurrency.sfuel.rawValue
        }
    }
}

// MARK: - Decimals
extension CryptoCurrency {
    public func getNumericPriceDecimalsPerCurrency(defaultValue: Int = 5) -> Int {
        switch self {
        case .eth: return defaultValue
        case .sol: return 5
        case .ada: return 4
        case .usdc: return 2
        default: return 6
        }
    }
}

// MARK: - Internal type
/// Internal enum providing compiler-enforced updates for CryptoCurrency.
///
/// This pattern exists to maintain CaseIterable conformance while supporting the .unknown case:
/// - Swift's auto-generated allCases doesn't work with associated values (.unknown(String))
/// - When adding a new currency, the compiler enforces updating both the `currency` computed
///   property (exhaustive switch) and indirectly the CryptoCurrency.name property
/// - Provides automatic CaseIterable.allCases generation which maps to CryptoCurrency.allCases
///
/// Without this pattern, allCases would need manual maintenance with no compiler verification.
private enum KnownCryptoCurrency: String, CaseIterable {
    case ape
    case eth
    case matic
    case pol
    case sei
    case chz
    case avax
    case xai
    case fuel
    case vic
    case ip
    case usdc
    case usdce
    case busd
    case usdxm
    case weth
    case degen
    case brett
    case toshi
    case eurc
    case superverse
    case bonk
    case wif
    case mother
    case sol
    case xlm
    case ada
    case bnb
    case sui
    case apt
    case sfuel

    var currency: CryptoCurrency {
        return switch self {
        case .ape: .ape
        case .eth: .eth
        case .matic: .matic
        case .pol: .pol
        case .sei: .sei
        case .chz: .chz
        case .avax: .avax
        case .xai: .xai
        case .fuel: .fuel
        case .vic: .vic
        case .ip: .ip
        case .usdc: .usdc
        case .usdce: .usdce
        case .busd: .busd
        case .usdxm: .usdxm
        case .weth: .weth
        case .degen: .degen
        case .brett: .brett
        case .toshi: .toshi
        case .eurc: .eurc
        case .superverse: .superverse
        case .bonk: .bonk
        case .wif: .wif
        case .mother: .mother
        case .sol: .sol
        case .xlm: .xlm
        case .ada: .ada
        case .bnb: .bnb
        case .sui: .sui
        case .apt: .apt
        case .sfuel: .sfuel
        }
    }
}
