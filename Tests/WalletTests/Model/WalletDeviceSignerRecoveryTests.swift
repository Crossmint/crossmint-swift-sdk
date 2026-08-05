import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let STALE_DEVICE_SIGNER_LOCATOR =
    "device:BC7k2LhzqCHurW97oXe/9YKI77h80kUwPy8pY2ot+7CWficNoWbwfHddNq4Itg304yMMpDCyHgZPxBJ0KH7Y9qc="

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    storage: MockDeviceSignerKeyStorage,
    fileName: String = "WalletSolanaEmail"
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: fileName,
        bundle: Bundle.module
    )
    return try SolanaWallet(
        smartWalletService: walletService,
        signer: MockSigner(),
        baseModel: baseModel,
        solanaChain: .solana,
        onTransactionStart: nil,
        deviceSignerKeyStorage: storage
    )
}

@Suite("Wallet Device Signer Recovery", .tags(.unit))
struct WalletDeviceSignerRecoveryTests {

    @Test
    func mapsKeyAndClearsRecoveryAfterSuccessfulRegistration() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: walletService, storage: storage)

        try await wallet.recover()

        #expect(await wallet.needsRecovery() == false)
        #expect(await storage.getKey(address: wallet.address) != nil)
    }

    @Test
    func removesTheStaleDeviceSignerAfterSuccessfulRecovery() async throws {
        let walletService = MockSmartWalletService()
        let removedTransaction: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.removeSignerResult = removedTransaction
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(
            walletService: walletService,
            storage: storage,
            fileName: "WalletSolanaEmailWithStaleDeviceSigner"
        )

        try await wallet.recover()

        #expect(await wallet.needsRecovery() == false)
        #expect(walletService.removeSignerCallCount == 1)
        #expect(walletService.removeSignerLastLocator == STALE_DEVICE_SIGNER_LOCATOR)
    }

    @Test
    func completesRecoveryWhenStaleSignerRemovalFails() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(
            walletService: walletService,
            storage: storage,
            fileName: "WalletSolanaEmailWithStaleDeviceSigner"
        )

        try await wallet.recover()

        #expect(await wallet.needsRecovery() == false)
        #expect(walletService.removeSignerCallCount == 1)
    }

    @Test
    func skipsRemovalWhenNoDeviceSignerWasPreviouslyRegistered() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: walletService, storage: storage)

        try await wallet.recover()

        #expect(walletService.removeSignerCallCount == 0)
    }

    @Test
    func rethrowsRegistrationErrorsOtherThanProviderRejection() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerError = .walletGeneric("registration exploded")
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: walletService, storage: storage)

        await #expect(throws: WalletError.self) {
            try await wallet.recover()
        }
        #expect(await wallet.needsRecovery())
    }

    @Suite("when the provider rejects device signers", .tags(.unit))
    struct ProviderRejectionTests {
        private func makeRejectedSolanaWallet(
            walletService: MockSmartWalletService,
            storage: MockDeviceSignerKeyStorage
        ) throws -> SolanaWallet {
            walletService.addSignerError = .deviceSignerNotSupported("Device signers are not supported")
            return try makeSolanaWallet(walletService: walletService, storage: storage)
        }

        @Test
        func fallsBackToTheRecoverySignerWithoutThrowing() async throws {
            let walletService = MockSmartWalletService()
            let storage = MockDeviceSignerKeyStorage()
            let wallet = try makeRejectedSolanaWallet(walletService: walletService, storage: storage)

            #expect(await wallet.needsRecovery())

            try await wallet.recover()

            #expect(await wallet.needsRecovery() == false)
            #expect(walletService.addSignerCallCount == 1)
            #expect(storage.deletePendingKeyCallCount == 1)
            #expect(storage.pendingKeys.isEmpty)
            #expect(await storage.getKey(address: wallet.address) == nil)
        }

        @Test
        func skipsRegistrationOnLaterRecoverCalls() async throws {
            let walletService = MockSmartWalletService()
            let storage = MockDeviceSignerKeyStorage()
            let wallet = try makeRejectedSolanaWallet(walletService: walletService, storage: storage)

            try await wallet.recover()
            try await wallet.recover()

            #expect(walletService.addSignerCallCount == 1)
        }

        @Test
        func remembersTheRejectionFromAnExplicitAddSigner() async throws {
            let walletService = MockSmartWalletService()
            let storage = MockDeviceSignerKeyStorage()
            let wallet = try makeRejectedSolanaWallet(walletService: walletService, storage: storage)

            await #expect {
                try await wallet.addSigner(.device)
            } throws: { error in
                guard case .deviceSignerNotSupported = error as? WalletError else { return false }
                return true
            }

            #expect(await wallet.needsRecovery() == false)
            try await wallet.recover()
            #expect(walletService.addSignerCallCount == 1)
        }

        @Test
        func throwsTypedErrorWhenSelectingTheDeviceSigner() async throws {
            let walletService = MockSmartWalletService()
            let storage = MockDeviceSignerKeyStorage()
            let wallet = try makeRejectedSolanaWallet(walletService: walletService, storage: storage)

            try await wallet.recover()

            await #expect {
                try await wallet.useSigner(.device)
            } throws: { error in
                guard case .deviceSignerNotSupported = error as? WalletError else { return false }
                return true
            }
        }
    }
}
