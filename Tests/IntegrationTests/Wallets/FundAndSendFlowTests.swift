import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: fund and send", Tier.integration)
struct FundAndSendFlowTests {
    @Test func fundsThenSendsWithTheRecoverySignerApprovingLocally() async throws {
        let sender = try await SessionPool.shared.primary()
        let recipient = try await SessionPool.shared.secondary()
        let wallet = try await SessionPool.shared.evmWallet(of: sender)
        let destination = try await SessionPool.shared.evmWallet(of: recipient)

        try await Funding.fund(wallet, usdxm: 5)
        let before = try await Funding.usdxmBalance(of: destination)
        let transfer = try await wallet.send(destination.address, IntegrationEnvironment.EVM_USDXM, 1)
        let after = try await Eventually.value(describing: "\(destination.address) receiving 1 USDXM") {
            let balance = try await Funding.usdxmBalance(of: destination)
            return balance >= before + 1 ? balance : nil
        }

        #expect(transfer.hash?.hasPrefix("0x") == true)
        #expect(after >= before + 1)
    }

    @Test func surfacesTheApiRejectionWhenTheBalanceIsInsufficient() async throws {
        let session = try await SessionPool.shared.primary()
        let wallet = try await SessionPool.shared.evmWallet(of: session)

        await #expect(throws: TransactionError.self) {
            _ = try await wallet.send(session.address, IntegrationEnvironment.EVM_USDXM, 1_000_000)
        }
    }
}
