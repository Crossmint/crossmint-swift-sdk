import CrossmintCommonTypes
import DeviceSigner
import Foundation
import SecureStorage
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet Creation", .tags(.unit), .serialized)
struct DefaultCrossmintWalletsTests {
    private final class StubSecureWalletStorage: SecureWalletStorage, @unchecked Sendable {
        func savePrivateKey(_ privateKey: String, forEmail email: String) {}
        func getPrivateKey(forEmail email: String) -> String? { nil }
    }

    private let walletService = MockSmartWalletService()
    private let keyStorage = MockDeviceSignerKeyStorage()

    private func makeWallets(fixture: String) throws -> DefaultCrossmintWallets {
        walletService.createWalletResult = try GetFromFile.getModelFrom(
            fileName: fixture,
            bundle: Bundle.module
        )
        DefaultCrossmintWallets.deviceSignerKeyStorageOverride = keyStorage
        return DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage()
        )
    }

    private func resetOverride() {
        DefaultCrossmintWallets.deviceSignerKeyStorageOverride = nil
    }

    @Test
    func includesDeviceSignerInEVMCreateRequest() async throws {
        defer { resetOverride() }

        let wallet = try await makeWallets(fixture: "WalletEVMEmail").createWallet(
            chain: Chain("base-sepolia"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        let entries = try #require(walletService.lastCreateWalletParams?.config.delegatedSigners)
        #expect(entries.count == 1)
        #expect(entries[0].signer.hasPrefix("device:"))
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(await keyStorage.getKey(address: wallet.address) != nil)
    }

    @Test
    func omitsDeviceSignerWhenNotRequested() async throws {
        defer { resetOverride() }

        let wallet = try await makeWallets(fixture: "WalletEVMEmail").createWallet(
            chain: Chain("base-sepolia"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: false)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
        #expect(wallet.deviceSignerKeyStorage == nil)
    }

    @Test
    func createsWalletWithoutDeviceSignerWhenKeyGenerationFails() async throws {
        defer { resetOverride() }
        keyStorage.generateKeyError = .keyGenerationFailed

        _ = try await makeWallets(fixture: "WalletEVMEmail").createWallet(
            chain: Chain("base-sepolia"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
    }

    @Test
    func deletesPendingKeyWhenAddressMappingFails() async throws {
        defer { resetOverride() }
        keyStorage.mapAddressToKeyError = .keyNotFound

        _ = try await makeWallets(fixture: "WalletEVMEmail").createWallet(
            chain: Chain("base-sepolia"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners?.count == 1)
        #expect(keyStorage.deletePendingKeyCallCount == 1)
        #expect(keyStorage.pendingKeys.isEmpty)
        #expect(keyStorage.keysByAddress.isEmpty)
    }

    @Test
    func skipsEagerDeviceSignerAttachForSolanaWallets() async throws {
        defer { resetOverride() }

        let wallet = try await makeWallets(fixture: "WalletSolanaEmail").createWallet(
            chain: Chain("solana"),
            recovery: MockSigner(),
            options: WalletOptions(deviceSigner: true)
        )

        #expect(walletService.lastCreateWalletParams?.config.delegatedSigners == nil)
        #expect(keyStorage.pendingKeys.isEmpty)
        // The storage must still reach the wallet so the deferred registration can run.
        #expect(wallet.deviceSignerKeyStorage != nil)
        #expect(await wallet.needsRecovery())
    }
}
