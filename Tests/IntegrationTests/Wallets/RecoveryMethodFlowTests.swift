import CrossmintCommonTypes
import Testing
@testable import Wallet

@Suite("Integration: recovery methods")
struct RecoveryMethodFlowTests {
    @Test func addsReadsBackAndRemovesARecoveryMethod() async throws {
        let session = try await CryptoWalletSession.start()
        let wallets = session.wallets()
        let wallet = try await wallets.createWallet(
            chain: IntegrationEnvironment.chain, recovery: session.keypair, options: nil
        )
        let second = try EVMKeyPairSigner()
        try await second.initialize(nil)
        let secondAddress = await second.evmAddress.address

        _ = try await wallet.addRecoveryMethod(.externalWallet(secondAddress))
        let withSecond = try #require(
            try await wallets.getWallet(chain: IntegrationEnvironment.chain, options: nil)
        )
        _ = try await wallet.removeRecoveryMethod(locator: .externalWallet(address: secondAddress))
        let withoutSecond = try #require(
            try await wallets.getWallet(chain: IntegrationEnvironment.chain, options: nil)
        )

        let locators = withSecond.config.recoveryMethods.map(\.locator)
        #expect(locators.contains("external-wallet:\(secondAddress)"))
        #expect(!withoutSecond.config.recoveryMethods.map(\.locator).contains("external-wallet:\(secondAddress)"))
    }
}
