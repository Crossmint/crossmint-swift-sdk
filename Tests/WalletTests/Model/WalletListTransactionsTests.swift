import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeEVMWallet(walletService: MockSmartWalletService) throws -> EVMWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletEVMEmail",
        bundle: Bundle.module
    )
    return try EVMWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        evmChain: .polygon
    )
}

@Suite("Wallet listTransactions", .tags(.unit))
struct WalletListTransactionsTests {
    @Test func returnsTransactionsFromTheService() async throws {
        let walletService = MockSmartWalletService()
        let model: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "GetTransactionResponse",
            bundle: Bundle.module
        )
        let expected = try #require(model.toDomain())
        walletService.listTransactionsResult = [expected]
        let wallet = try makeEVMWallet(walletService: walletService)

        let transactions = try await wallet.listTransactions()

        #expect(transactions.map(\.id) == [expected.id])
    }

    @Test func passesTheWalletsChainTypeToTheService() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeEVMWallet(walletService: walletService)

        _ = try await wallet.listTransactions()

        #expect(walletService.listTransactionsCallCount == 1)
        #expect(walletService.lastListTransactionsChainType == .evm)
    }

    @Test func propagatesTransactionErrorFromTheService() async throws {
        let walletService = MockSmartWalletService()
        walletService.listTransactionsError = .transactionGeneric("boom")
        let wallet = try makeEVMWallet(walletService: walletService)

        await #expect(throws: TransactionError.self) {
            _ = try await wallet.listTransactions()
        }
    }
}
