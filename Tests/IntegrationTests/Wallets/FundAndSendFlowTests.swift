import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: fund and send")
struct FundAndSendFlowTests {
    @Test func fundsThenSendsWithTheRecoverySignerApprovingLocally() async throws {
        let sender = try await CryptoWalletSession.start()
        let recipient = try await CryptoWalletSession.start()
        let wallet = try await sender.wallets().createWallet(
            chain: IntegrationEnvironment.chain, recovery: sender.keypair, options: nil
        )
        let destination = try await recipient.wallets().createWallet(
            chain: IntegrationEnvironment.chain, recovery: recipient.keypair, options: nil
        )

        try await wallet.fund(token: .usdxm, amount: 5)
        let funded = try await wallet.balances([.usdxm])
        let transfer = try await wallet.send(destination.address, IntegrationEnvironment.tokenLocator, 1)
        let received = try await destination.balances([.usdxm])

        #expect(funded.tokens.contains { $0.token == .usdxm && $0.amount != "0" })
        #expect(transfer.hash.hasPrefix("0x"))
        #expect(received.tokens.contains { $0.token == .usdxm && $0.amount != "0" })
    }

    @Test func surfacesTheApiRejectionWhenTheBalanceIsInsufficient() async throws {
        let session = try await CryptoWalletSession.start()
        let wallet = try await session.wallets().createWallet(
            chain: IntegrationEnvironment.chain, recovery: session.keypair, options: nil
        )

        await #expect(throws: TransactionError.self) {
            _ = try await wallet.send(session.address, IntegrationEnvironment.tokenLocator, 1)
        }
    }
}
