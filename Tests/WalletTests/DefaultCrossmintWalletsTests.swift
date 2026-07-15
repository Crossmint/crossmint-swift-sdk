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
            deviceSignerStorage: keyStorage
        )
    }

    private func loadSolanaWalletFixture() throws -> WalletApiModel {
        try GetFromFile.getModelFrom(fileName: "WalletSolanaEmail", bundle: Bundle.module)
    }

    @Test
    func includesDeviceSignerInSolanaCreateRequest() async throws {
        walletService.createWalletResult = try loadSolanaWalletFixture()

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        let entries = try #require(walletService.lastCreateWalletParams?.config.delegatedSigners)
        #expect(entries.count == 1)
        #expect(entries[0].signer.hasPrefix("device:"))
        #expect(walletService.createWalletCallCount == 1)
        #expect(keyStorage.keysByAddress[wallet.address] != nil)
        #expect(wallet.deviceSignerKeyStorage != nil)
    }

    @Test
    func retriesOnceWithoutDeviceSignerWhenProviderRejectsIt() async throws {
        walletService.createWalletResult = try loadSolanaWalletFixture()
        walletService.createWalletErrors = [.deviceSignerNotSupported("not supported")]

        let wallet = try await makeWallets().createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.createWalletCallCount == 2)
        #expect(walletService.allCreateWalletParams[0].config.delegatedSigners != nil)
        #expect(walletService.allCreateWalletParams[1].config.delegatedSigners == nil)
        #expect(keyStorage.deletePendingKeyCallCount == 1)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(wallet.deviceSignerKeyStorage != nil)
    }

    @Test
    func surfacesOtherCreateErrorsWithoutRetrying() async throws {
        walletService.createWalletResult = try loadSolanaWalletFixture()
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
        #expect(keyStorage.deletePendingKeyCallCount == 0)
    }

    @Test
    func omitsDeviceSignerWhenNotRequested() async throws {
        walletService.createWalletResult = try loadSolanaWalletFixture()

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
