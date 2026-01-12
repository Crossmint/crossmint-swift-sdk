import CrossmintCommonTypes
import Foundation

public enum TransferTokenLocator: CustomStringConvertible, Equatable, Hashable, Encodable {
     public enum CurrencyData: CustomStringConvertible, Equatable, Hashable, Encodable {
        case evm(EVMChain, CryptoCurrency)
        case solana(SolanaSupportedToken)
        case stellar(StellarSupportedToken)

        public var description: String {
            switch self {
            case .evm(let chain, let currency):
                return "\(chain.name):\(currency.name)"
            case .solana(let token):
                return "\(Chain.solana.name):\(token.asCryptoCurrency.name)"
            case .stellar(let token):
                return "\(Chain.stellar.name):\(token.asCryptoCurrency.name)"
            }
        }
    }

    case tokenId(ChainAndAddress, tokenId: String)
    case currency(CurrencyData)
    case address(ChainAndAddress)

    public var description: String {
        switch self {
        case .tokenId(let tuple, let tokenId):
            return "\(tuple.description):\(tokenId)"
        case .currency(let data):
            return "\(data.description)"
        case .address(let tuple):
            return "\(tuple.description)"
        }
    }

    public func matches(_ string: String) -> Bool {
        return self.description == string
    }
}

extension TransferTokenLocator {
    public static func == (lhs: TransferTokenLocator, rhs: String) -> Bool {
        return lhs.matches(rhs)
    }

    public static func == (lhs: String, rhs: TransferTokenLocator) -> Bool {
        return rhs.matches(lhs)
    }

    public static func != (lhs: TransferTokenLocator, rhs: String) -> Bool {
        return !lhs.matches(rhs)
    }

    public static func != (lhs: String, rhs: TransferTokenLocator) -> Bool {
        return !rhs.matches(lhs)
    }
}
