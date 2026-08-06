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
    private let keyStorage = MockDeviceSignerKeyStorage()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: keyStorage
        )
    }

    private func loadSolanaWalletFixture() throws -> Data {
        let url = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test
    func includesDeviceSignerInSolanaCreateRequest() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        let entries = try #require(walletService.lastCreateWalletParams?.config.delegatedSigners)
        #expect(entries.count == 1)
        #expect(entries[0].signer.hasPrefix("device:"))
        #expect(walletService.createWalletCallCount == 1)
        #expect(await wallet.needsRecovery() == false)
        try await wallet.useSigner(.device)
        #expect(wallet.selectedSignerLocator?.hasPrefix("device:") == true)
    }

    @Test
    func retriesOnceWithoutDeviceSignerWhenProviderRejectsIt() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        walletService.createWalletErrors = [.deviceSignerNotSupported("not supported")]

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.createWalletCallCount == 2)
        #expect(walletService.allCreateWalletParams[0].config.delegatedSigners != nil)
        #expect(walletService.allCreateWalletParams[1].config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(await wallet.needsRecovery() == false)
        await #expect {
            try await wallet.useSigner(.device)
        } throws: { error in
            guard case .deviceSignerNotSupported = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test
    func surfacesOtherCreateErrorsWithoutRetrying() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()
        walletService.createWalletErrors = [.walletGeneric("backend down")]
        let wallets = makeWallets()

        await #expect {
            _ = try await wallets.createWallet(
                chain: Chain("solana"),
                recovery: MockSigner(),
                options: WalletOptions(deviceSigner: true)
            )
        } throws: { error in
            guard case .walletGeneric = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.createWalletCallCount == 1)
        #expect(keyStorage.deletePendingKeyCallCount == 1)
        #expect(keyStorage.pendingKeys.isEmpty)
    }

    @Test
    func omitsDeviceSignerWhenNotRequested() async throws {
        walletService.createWalletFixture = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: false)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(wallet.deviceSignerKeyStorage == nil)
    }
}
