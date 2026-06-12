import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    storage: MockDeviceSignerKeyStorage
) throws -> SolanaWallet {
    let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
        fileName: "WalletSolanaEmail",
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
