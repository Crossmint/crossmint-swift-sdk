import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct FetchTransactionResponseTest {
    @Test("Parse failed transactions")
    func willParseAwaitingApprovalState() async throws {
        let response: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "FailedTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .failed)
        #expect(response.toDomain().error?.revert?.reason == "This contract call reverted with no data")
    }
}
