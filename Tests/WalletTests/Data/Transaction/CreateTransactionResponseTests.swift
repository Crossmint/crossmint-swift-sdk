import Foundation
import Testing
import TestsUtils

@testable import Wallet

struct CreateTransactionResponseTest {
    @Test("Parse awaiting approval state")
    func willParseAwaitingApprovalState() async throws {
        let response: EVMTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateTransactionAwaitingApproval",
            bundle: Bundle.module
        )

        #expect(response.status == .awaitingApproval)
        #expect(response.approvals?.pending.count == 1)
    }

    @Test("Parse Solana transaction state")
    func willParseSolanaTransactionResponse() async throws {
        let response: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateSolanaTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .awaitingApproval)
        #expect(response.approvals?.pending.count == 1)
        #expect(response.approvals?.required == 1)
        #expect(response.sendParams?.token == "solana:sol")
        #expect(response.sendParams?.params.amount == "0.5")
    }

    @Test("Parse stellar transaction with string signer in params")
    func willParseStellarTransactionResponseWithStringSigner() async throws {
        let response: StellarTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "CreateStellarTransactionResponse",
            bundle: Bundle.module
        )

        #expect(response.status == .awaitingApproval)
        #expect(response.params.signer?.locator == "email:user@example.com")
        #expect(response.approvals?.pending.count == 1)
        #expect(response.approvals?.pending.first?.signer.locator == "email:user@example.com")
        #expect(response.sendParams?.params.amount == "1")
    }
}
