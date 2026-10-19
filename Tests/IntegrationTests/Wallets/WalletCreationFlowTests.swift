import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: wallet creation")
struct WalletCreationFlowTests {
    @Test func createsAWalletWithAnExternalWalletRecoveryAndReadsItBack() async throws {
        let session = try await CryptoWalletSession.start()
        let wallets = session.wallets()

        let created = try await wallets.createWallet(
            chain: IntegrationEnvironment.chain,
            recovery: session.keypair,
            options: nil
        )
        let fetched = try #require(
            try await wallets.getWallet(chain: IntegrationEnvironment.chain, options: nil)
        )

        #expect(created.address.hasPrefix("0x"))
        #expect(fetched.address == created.address)
        #expect(fetched.config.recovery.locator == "external-wallet:\(session.address)")
    }

    @Test func reportsNoWalletForAUserWhoNeverCreatedOne() async throws {
        let session = try await CryptoWalletSession.start()

        let wallet = try await session.wallets().getWallet(chain: IntegrationEnvironment.chain, options: nil)

        #expect(wallet == nil)
    }
}
