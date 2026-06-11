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

    // Solana must not include a device signer in the create request: provider support is
    // only known server-side, so registration defers to the first recover().
    @Test
    func skipsEagerDeviceSignerAttachForSolanaWallets() async throws {
        let walletService = MockSmartWalletService()
        walletService.createWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaEmail",
            bundle: Bundle.module
        )
        let wallets = DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage()
        )

        let wallet = try await wallets.createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        // The storage must still reach the wallet so the deferred registration can run.
        #expect(wallet.deviceSignerKeyStorage != nil)
        #expect(await wallet.needsRecovery())
    }
}
