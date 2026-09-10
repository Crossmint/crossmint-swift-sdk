import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet removeSigner", .tags(.unit))
struct WalletRemoveSignerTests {

    @Test func sendsTheLocatorStringToTheWalletService() async throws {
        let walletService = MockSmartWalletService()
        let removedTransaction: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.removeSignerResult = removedTransaction
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaEmail",
            bundle: Bundle.module
        )
        let wallet = try SolanaWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            solanaChain: .solana,
            onTransactionStart: nil
        )

        _ = try await wallet.removeSigner(locator: .email("test@example.com"))

        #expect(walletService.removeSignerLastLocator == "email:test@example.com")
    }
}
