import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: wallet creation", Tier.integration)
struct WalletCreationFlowTests {
    @Test func createsAWalletWithAnExternalWalletRecoveryAndReadsItBack() async throws {
        let session = try await SessionPool.shared.primary()

        let wallet = try await SessionPool.shared.evmWallet(of: session)
        let again = try #require(
            try await session.wallets().getWallet(chain: IntegrationEnvironment.EVM_CHAIN, options: nil)
        )

        #expect(wallet.address.hasPrefix("0x"))
        #expect(again.address == wallet.address)
        #expect(again.config.recovery.locator == "external-wallet:\(session.address)")
    }

    @Test func reportsNoWalletOnAChainTheUserNeverCreatedOneOn() async throws {
        let session = try await SessionPool.shared.secondary()

        let wallet = try await session.wallets().getWallet(chain: IntegrationEnvironment.SOLANA_CHAIN, options: nil)

        #expect(wallet == nil)
    }
}
