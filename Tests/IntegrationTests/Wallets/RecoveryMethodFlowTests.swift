import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: recovery methods")
struct RecoveryMethodFlowTests {
    @Test func addsReadsBackAndRemovesARecoveryMethodOnSolana() async throws {
        let session = try await CryptoWalletSession.start()
        let wallets = session.wallets()
        let primary = SolanaKeypairSigner()
        let second = SolanaKeypairSigner()
        let wallet = try await wallets.createWallet(
            chain: IntegrationEnvironment.SOLANA_CHAIN, recovery: primary, options: nil
        )

        _ = try await wallet.addRecoveryMethod(second.config)
        let withSecond = try #require(
            try await wallets.getWallet(chain: IntegrationEnvironment.SOLANA_CHAIN, options: nil)
        )
        _ = try await wallet.removeRecoveryMethod(locator: .externalWallet(address: second.address))
        let withoutSecond = try #require(
            try await wallets.getWallet(chain: IntegrationEnvironment.SOLANA_CHAIN, options: nil)
        )

        let secondLocator = second.adminSigner.locator
        let added = withSecond.config.recoveryMethodsWithStatus.first { $0.signer.locator == secondLocator }
        #expect(added != nil)
        #expect(added?.status == .active)
        #expect(!withoutSecond.config.recoveryMethods.map(\.locator).contains(second.adminSigner.locator))
    }
}
