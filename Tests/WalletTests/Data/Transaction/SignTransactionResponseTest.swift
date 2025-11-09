import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct SignTransactionResponseTest {
    @Test("Will parse transaction when signed")
    func willParseTransactionWhenSigned() async throws {
        let response: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SignTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .pending)
        #expect(response.approvals.pending.isEmpty)
        #expect(response.approvals.submitted.count == 1)
    }
}
