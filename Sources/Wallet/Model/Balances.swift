import CrossmintCommonTypes
import Foundation
import Logger
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
                if balancesMap[balance.token] == nil {
                    balancesMap[balance.token] = balance.balances
                }
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

    private struct TokenAmountApiModel: Decodable {
        let amount: String
        let rawAmount: String

        var toDomain: TokenAmount {
            TokenAmount(amount: amount, rawAmount: rawAmount)
        }
    }

    private struct TokenAccountApiModel: Decodable {
        let type: String?
        let provider: String?
        let amount: String
        let rawAmount: String
        let available: TokenAmountApiModel
        let locked: TokenAmountApiModel

        var toDomain: TokenAccountBalance {
            TokenAccountBalance(
                type: accountType,
                amount: amount,
                rawAmount: rawAmount,
                available: available.toDomain,
                locked: locked.toDomain
            )
        }

        private var accountType: TokenAccountType {
            let rawType = type ?? ""
            switch rawType {
            case "wallet":
                return .wallet
            case "card":
                guard let provider else { return .unknown(rawType) }
                return .card(provider: provider)
            default:
                return .unknown(rawType)
            }
        }
    }

    private struct LossyDecoded<Wrapped: Decodable>: Decodable {
        let value: Wrapped?
        let failure: String?

        init(from decoder: any Decoder) throws {
            do {
                value = try Wrapped(from: decoder)
                failure = nil
            } catch {
                value = nil
                failure = "\(error)"
            }
        }
    }

    private struct ChainInfo: Decodable {
        let amount: String
        let contractAddress: String?
        let available: LossyDecoded<TokenAmountApiModel>?
        let locked: LossyDecoded<TokenAmountApiModel>?
        let accounts: LossyDecoded<[LossyDecoded<TokenAccountApiModel>]>?

        func detail(on chain: String) -> ChainBalanceDetail {
            ChainBalanceDetail(
                available: tokenAmount(available, field: "available", chain: chain),
                locked: tokenAmount(locked, field: "locked", chain: chain),
                accounts: accountBalances(on: chain)
            )
        }

        private func tokenAmount(
            _ decoded: LossyDecoded<TokenAmountApiModel>?,
            field: String,
            chain: String
        ) -> TokenAmount? {
            guard let decoded else { return nil }
            guard let value = decoded.value else {
                Logger.smartWallet.warning(LogEvents.walletBalancesMalformedAmount, attributes: [
                    "chain": chain,
                    "field": field,
                    "error": decoded.failure ?? ""
                ])
                return nil
            }
            return value.toDomain
        }

        private func accountBalances(on chain: String) -> [TokenAccountBalance]? {
            guard let decoded = accounts else { return nil }
            guard let entries = decoded.value else {
                Logger.smartWallet.warning(LogEvents.walletBalancesMalformedAccounts, attributes: [
                    "chain": chain,
                    "error": decoded.failure ?? ""
                ])
                return nil
            }

            return entries.compactMap { entry in
                guard let account = entry.value else {
                    Logger.smartWallet.warning(LogEvents.walletBalancesSkippedAccount, attributes: [
                        "chain": chain,
                        "error": entry.failure ?? ""
                    ])
                    return nil
                }

                let balance = account.toDomain
                if case .unknown(let rawType) = balance.type {
                    Logger.smartWallet.warning(LogEvents.walletBalancesUnknownAccountType, attributes: [
                        "chain": chain,
                        "type": rawType
                    ])
                }
                return balance
            }
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let token = CryptoCurrency(name: try container.decode(String.self, forKey: .symbol))
        self.token = token
        self.decimals = try container.decode(Int.self, forKey: .decimals)

        let amount = try container.decode(String.self, forKey: .amount)
        let total = Decimal(string: amount) ?? .zero

        let rawAmountString = try container.decodeIfPresent(String.self, forKey: .rawAmount)
        let rawAmount = rawAmountString.flatMap { Self.readable($0, of: token) }

        var balances: [Chain: Decimal] = [:]
        var details: [Chain: ChainBalanceDetail] = [:]
        let chainsContainer = try container.nestedContainer(
            keyedBy: DynamicCodingKeys.self, forKey: .chains)

        for key in chainsContainer.allKeys {
            let chain = Chain(key.stringValue)
            let chainInfo = try chainsContainer.decode(ChainInfo.self, forKey: key)
            balances[chain] = Decimal(string: chainInfo.amount) ?? .zero
            details[chain] = chainInfo.detail(on: key.stringValue)
        }

        self.balances = ChainBalances(
            total: total,
            reportedAmount: amount,
            reportedRawAmount: rawAmount,
            decimals: decimals,
            chainBalances: balances,
            chainDetails: details
        )
    }

    private static func readable(_ rawAmount: String, of token: CryptoCurrency) -> String? {
        guard Decimal(string: rawAmount) != nil else {
            Logger.smartWallet.warning(LogEvents.walletBalancesMalformedAmount, attributes: [
                "token": token.name,
                "field": "rawAmount",
                "value": rawAmount
            ])
            return nil
        }

        return rawAmount
    }
}

struct ChainBalanceDetail: Sendable, Equatable {
    let available: TokenAmount?
    let locked: TokenAmount?
    let accounts: [TokenAccountBalance]?
}

public struct ChainBalances: Sendable, Equatable {
    public let total: Decimal
    public let decimals: Int
    public let chainBalances: [Chain: Decimal]
    let reportedAmount: String
    let reportedRawAmount: String?
    let chainDetails: [Chain: ChainBalanceDetail]

    init(
        total: Decimal,
        reportedAmount: String,
        reportedRawAmount: String?,
        decimals: Int,
        chainBalances: [Chain: Decimal],
        chainDetails: [Chain: ChainBalanceDetail] = [:]
    ) {
        self.total = total
        self.reportedAmount = reportedAmount
        self.reportedRawAmount = reportedRawAmount
        self.decimals = decimals
        self.chainBalances = chainBalances
        self.chainDetails = chainDetails
    }

    public subscript(chain: Chain) -> Decimal {
        chainBalances[chain] ?? .zero
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
