import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("FetchTransactionResponse Tests")
struct FetchTransactionResponseTest {
    @Test("Parse failed transactions")
    func parsesFailedTransactionState() async throws {
        let response: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "FailedTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .failed)
        #expect(response.error != nil)
    }
}
