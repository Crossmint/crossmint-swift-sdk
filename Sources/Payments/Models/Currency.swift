import CrossmintCommonTypes
import Foundation

public enum Currency: Sendable, Hashable, Comparable, RangeExpression {
    case crypto(CryptoCurrency)
    case fiat(FiatCurrency)
    case unknown(String)

    public init(name: String) throws {
        let fiat = FiatCurrency(name: name)
        if case .unknown = fiat {
            let crypto = CryptoCurrency(name: name)
            if case .unknown = crypto {
                self = .unknown(name)
            } else {
                self = .crypto(crypto)
            }
        } else {
            self = .fiat(fiat)
        }
    }

    public var name: String {
        switch self {
        case .crypto(let cryptoCurrency):
            return cryptoCurrency.name
        case .fiat(let fiatCurrency):
            return fiatCurrency.name
        case .unknown(let name):
            return name
        }
    }

    // MARK: - Comparable
    public static func < (lhs: Currency, rhs: Currency) -> Bool {
        return lhs.name < rhs.name
    }

    // MARK: - RangeExpression
    public func relative<C>(to collection: C) -> Range<Currency>
    where C: Collection, Currency == C.Index {
        return self..<self
    }

    public func contains(_ element: Currency) -> Bool {
        return self == element
    }

    public func relative<C>(to collection: C) -> Range<C.Index> where C: Collection {
        let idx =
            collection.firstIndex(where: { ($0 as? Currency) == self }) ?? collection.startIndex
        return idx..<collection.index(after: idx)
    }
}

// MARK: - Codable Conformance
extension Currency: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let currencyString = try container.decode(String.self)

        do {
            self = try Currency(name: currencyString)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown currency: \(currencyString)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}

// MARK: - Convenience Methods
extension Currency {
    public var isCrypto: Bool {
        if case .crypto = self {
            return true
        }
        return false
    }

    public var isFiat: Bool {
        if case .fiat = self {
            return true
        }
        return false
    }

    public var asCrypto: CryptoCurrency? {
        if case .crypto(let cryptoCurrency) = self {
            return cryptoCurrency
        }
        return nil
    }

    public var asFiat: FiatCurrency? {
        if case .fiat(let fiatCurrency) = self {
            return fiatCurrency
        }
        return nil
    }
}
