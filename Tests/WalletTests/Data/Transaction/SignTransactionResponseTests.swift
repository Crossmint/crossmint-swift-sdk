import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("SignTransactionResponse Tests", .tags(.unit))
struct SignTransactionResponseTest {
    @Test("Parses transaction when signed")
    func parsesTransactionWhenSigned() async throws {
        let response: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SignTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .pending)
        #expect(response.approvals?.pending.isEmpty == true)
        #expect(response.approvals?.submitted.count == 1)
    }
}
