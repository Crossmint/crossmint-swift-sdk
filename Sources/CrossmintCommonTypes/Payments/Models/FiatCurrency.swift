public enum FiatCurrency: Codable, Sendable, Hashable, Comparable, RangeExpression {
    case usd
    case eur
    case aud
    case gbp
    case jpy
    case sgd
    case hkd
    case krw
    case inr
    case vnd
    case unknown(String)

    public init(name: String) {
        self = KnownFiatCurrency(rawValue: name).map(\.currency) ?? .unknown(name)
    }

    // Comparable requirement
    public static func < (lhs: FiatCurrency, rhs: FiatCurrency) -> Bool {
        return lhs.name < rhs.name
    }

    // RangeExpression requirements
    public func relative<C>(to collection: C) -> Range<FiatCurrency>
    where C: Collection, FiatCurrency == C.Index {
        return self..<self
    }

    public func contains(_ element: FiatCurrency) -> Bool {
        return self == element
    }

    public func relative<C>(to collection: C) -> Range<C.Index> where C: Collection {
        let idx =
            collection.firstIndex(where: { ($0 as? FiatCurrency) == self })
            ?? collection.startIndex
        return idx..<collection.index(after: idx)
    }

    public var name: String {
        return switch self {
        case .unknown(let name):
            name
        case .usd:
            KnownFiatCurrency.usd.rawValue
        case .eur:
            KnownFiatCurrency.eur.rawValue
        case .aud:
            KnownFiatCurrency.aud.rawValue
        case .gbp:
            KnownFiatCurrency.gbp.rawValue
        case .jpy:
            KnownFiatCurrency.jpy.rawValue
        case .sgd:
            KnownFiatCurrency.sgd.rawValue
        case .hkd:
            KnownFiatCurrency.hkd.rawValue
        case .krw:
            KnownFiatCurrency.krw.rawValue
        case .inr:
            KnownFiatCurrency.inr.rawValue
        case .vnd:
            KnownFiatCurrency.vnd.rawValue
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}

private enum KnownFiatCurrency: String {
    case usd
    case eur
    case aud
    case gbp
    case jpy
    case sgd
    case hkd
    case krw
    case inr
    case vnd

    var currency: FiatCurrency {
        return switch self {
        case .usd: .usd
        case .eur: .eur
        case .aud: .aud
        case .gbp: .gbp
        case .jpy: .jpy
        case .sgd: .sgd
        case .hkd: .hkd
        case .krw: .krw
        case .inr: .inr
        case .vnd: .vnd
        }
    }
}

// MARK: - Payment Related
extension FiatCurrency {
    public var isPaymentEnabledFiatCurrency: Bool {
        switch self {
        case .usd, .eur, .gbp, .jpy, .aud, .sgd, .hkd, .krw, .inr, .vnd:
            return true
        case .unknown:
            return false
        }
    }
}
