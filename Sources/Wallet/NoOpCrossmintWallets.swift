import CrossmintCommonTypes
import Foundation

public struct NoOpCrossmintWallets: CrossmintWallets {
    private let genericWalletError = WalletError.walletGeneric(
        "Crossmint SDK was not initialized properly. Please check your API key."
    )

    private let genericTransactionError = TransactionError.transactionGeneric(
        "Crossmint SDK was not initialized properly. Please check your API key."
    )

    public init() {}

    public func getOrCreateWallet(
        chain: Chain,
        signer: any Signer,
        options: WalletOptions? = nil
    ) async throws(WalletError) -> Wallet {
        throw genericWalletError
    }

    public func getTransaction(
        id: String,
        type: WalletType
    ) async throws(TransactionError) -> Transaction {
        throw genericTransactionError
    }
}
