import CrossmintCommonTypes
import Foundation
import SecureStorage
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet Creation", .tags(.unit))
struct DefaultCrossmintWalletsTests {
    private final class StubSecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
        func savePrivateKey(_ privateKey: String, forEmail email: String) {}
        func getPrivateKey(forEmail email: String) -> String? { nil }
    }

    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage()
        )
    }

    private func loadSolanaWalletFixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test
    func omitsDeviceSignerWhenNotRequested() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: false)
        )

        #expect(walletService.createWalletCallCount == 1)
        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(wallet.deviceSignerKeyStorage == nil)
    }

    @Test
    func createsWalletWithoutDeviceSignerWhenKeyGenerationFails() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        _ = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.createWalletCallCount == 1)
        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(walletService.addSignerCallCount == 0)
    }
}
