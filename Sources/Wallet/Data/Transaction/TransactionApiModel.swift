import CrossmintCommonTypes
import Foundation

public protocol TransactionApiModel: Decodable, Identifiable {
    func toDomain() -> Transaction
}

public protocol WalletTypeTransactionMapping {
    associatedtype APIModel: TransactionApiModel
    static var chainType: ChainType { get }
}

public enum EVMSmartWalletMapping: WalletTypeTransactionMapping {
    public typealias APIModel = EVMTransactionApiModel
    public static let chainType: ChainType = .evm
}

public enum SolanaSmartWalletMapping: WalletTypeTransactionMapping {
    public typealias APIModel = SolanaTransactionApiModel
    public static let chainType: ChainType = .solana
}

public enum StellarSmartWalletMapping: WalletTypeTransactionMapping {
    public typealias APIModel = StellarTransactionApiModel
    public static let chainType: ChainType = .stellar
}
