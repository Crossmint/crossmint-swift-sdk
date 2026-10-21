import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: recovery methods", Tier.integration)
struct RecoveryMethodFlowTests {
    @Test func addsReadsBackAndRemovesARecoveryMethodOnSolana() async throws {
        let session = try await SessionPool.shared.primary()
        let (wallet, _) = try await SessionPool.shared.solanaWallet(of: session)
        let second = SolanaKeypairSigner()
        let secondLocator = second.adminSigner.locator

        _ = try await wallet.addRecoveryMethod(second.config)
        let withSecond = try #require(
            try await session.wallets().getWallet(chain: IntegrationEnvironment.SOLANA_CHAIN, options: nil)
        )
        _ = try await wallet.removeRecoveryMethod(locator: .externalWallet(address: second.address))
        let withoutSecond = try #require(
            try await session.wallets().getWallet(chain: IntegrationEnvironment.SOLANA_CHAIN, options: nil)
        )

        let added = withSecond.config.recoveryMethodsWithStatus.first { $0.signer.locator == secondLocator }
        #expect(added != nil)
        #expect(added?.status == .active)
        #expect(!withoutSecond.config.recoveryMethods.map(\.locator).contains(secondLocator))
    }
}
