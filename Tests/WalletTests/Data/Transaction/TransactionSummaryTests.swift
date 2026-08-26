import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Transaction Summary", .tags(.unit))
struct TransactionSummaryTests {
    @Test func exposesCrossmintIdAsTransactionIDAndOnChainTxIdAsHash() async throws {
        let model: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "GetTransactionResponse",
            bundle: Bundle.module
        )
        let transaction = try #require(model.toDomain())

        let summary = try #require(transaction.toCompleted()).summary

        #expect(summary.transactionID == "42bbb192-1707-43ba-bd21-6e96d28bdcc9")
        #expect(summary.hash == "0x9f52ec9b7e3a6a5c6a4d2f1f0f7f3f0a4a1b2c3d4e5f60718293a4b5c6d7e8f9")
        #expect(summary.explorerLink.absoluteString.contains(summary.hash))
    }
}
