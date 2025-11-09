import CrossmintCommonTypes
import Foundation
import Utils

public struct Balances: Decodable, Sendable, Equatable {
    private let balancesMap: [CryptoCurrency: ChainBalances]

    init() {
        balancesMap = [:]
    }

    /// Initializes a new Balances object with the provided balances map
    /// - Parameter balancesMap: A dictionary mapping crypto currencies to their chain balances
    init(balancesMap: [CryptoCurrency: ChainBalances]) {
        self.balancesMap = balancesMap
    }

    public subscript(currency: CryptoCurrency) -> ChainBalances? {
        balancesMap[currency]
    }

    public var isEmpty: Bool {
        balancesMap.isEmpty
    }

    public var tokens: [CryptoCurrency] {
        Array(balancesMap.keys)
    }

    public func filter(_ isIncluded: (CryptoCurrency, ChainBalances) -> Bool) -> Balances {
        let filteredMap = balancesMap.filter { currency, chainBalances in
            isIncluded(currency, chainBalances)
        }

        return Balances(balancesMap: filteredMap)
    }

    public func nonZeroBalances() -> Balances {
        filter { _, chainBalances in
            chainBalances.total > 0
        }
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var balancesMap: [CryptoCurrency: ChainBalances] = [:]
        while !container.isAtEnd {
            if let balance = try? container.decode(BalanceEntry.self) {
                balancesMap[balance.token] = balance.balances.merge(
                    with: balancesMap[balance.token])
            } else {
                // Skip invalid entry by decoding it as a nested container
                _ = try? container.decode(AnyCodable.self)
            }
        }

        self.balancesMap = balancesMap
    }
}

private struct BalanceEntry: Decodable, Sendable {
    let token: CryptoCurrency
    let balances: ChainBalances
    let decimals: Int

    private enum CodingKeys: String, CodingKey {
        case symbol
        case decimals
        case amount
        case rawAmount
        case chains
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            return nil
        }
    }

    private struct ChainInfo: Decodable {
        let locator: String
        let amount: String
        let rawAmount: String
        let contractAddress: String?
    }

    init(currency: CryptoCurrency, balances: ChainBalances, decimals: Int) {
        self.token = currency
        self.balances = balances
        self.decimals = decimals
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.token = CryptoCurrency(name: try container.decode(String.self, forKey: .symbol))
        self.decimals = try container.decode(Int.self, forKey: .decimals)

        // Parse total from amount field
        let amountString = try container.decode(String.self, forKey: .amount)
        let total = Decimal(string: amountString) ?? .zero

        // Parse chain balances from chains object
        var balances: [Chain: Decimal] = [:]
        let chainsContainer = try container.nestedContainer(
            keyedBy: DynamicCodingKeys.self, forKey: .chains)

        for key in chainsContainer.allKeys {
            let chain = Chain(key.stringValue)
            let chainInfo = try chainsContainer.decode(ChainInfo.self, forKey: key)
            balances[chain] = Decimal(string: chainInfo.amount) ?? .zero
        }

        self.balances = ChainBalances(total: total, decimals: decimals, chainBalances: balances)
    }
}

public struct ChainBalances: Sendable, Equatable {
    public let total: Decimal
    public let decimals: Int
    public let chainBalances: [Chain: Decimal]

    public subscript(chain: Chain) -> Decimal {
        chainBalances[chain] ?? .zero
    }

    public func merge(with other: ChainBalances?) -> ChainBalances {
        ChainBalances(
            total: self.total + (other?.total ?? .zero),
            decimals: self.decimals,
            chainBalances: self.chainBalances.merging(with: other?.chainBalances)
        )
    }

    public func convertToBaseUnits(_ value: String) -> String? {
        guard let decimalValue = Decimal(string: value) else {
            return nil
        }

        let multiplier = pow(10, decimals)
        let normalizedValue = decimalValue * multiplier

        // Convert to string without scientific notation
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = ""

        return formatter.string(from: normalizedValue as NSDecimalNumber) ?? nil
    }
}

extension Dictionary where Key == Chain, Value == Decimal {
    func merging(with other: [Chain: Decimal]?) -> [Chain: Decimal] {
        guard let other = other else { return self }
        var result = self

        for (chain, value) in other {
            result[chain, default: 0] += value
        }

        return result
    }
}
