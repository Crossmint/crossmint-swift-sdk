import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private func makeSolanaWallet(
    walletService: MockSmartWalletService,
    storage: MockDeviceSignerKeyStorage,
    fileName: String = "WalletSolanaEmail"
) throws -> SolanaWallet {
    let fixtureUrl = try #require(Bundle.module.url(forResource: fileName, withExtension: "json"))
    walletService.getWalletFixture = try Data(contentsOf: fixtureUrl)
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
    @Test func dropsThePendingKeyOnceCrossmintCancelledItsRegistration() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: walletService, storage: storage, fileName: "WalletSolanaQuorum")
        let publicKey = try await storage.generateKey(address: nil)
        wallet.pendingDeviceKey = PendingDeviceKey(
            transactionId: "5b1d3e0c-7a42-4c8e-9f16-2e7d8a9b0c31",
            publicKeyBase64: publicKey,
            storage: storage
        )
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "SolanaQuorumTransactionCancelled",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel

        _ = try? await wallet.recover()

        #expect(storage.deletePendingKeyCallCount == 1)
        #expect(wallet.pendingDeviceKey?.publicKeyBase64 != publicKey)
    }

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
    func keepsTheDeviceSignerThatWasAlreadyRegistered() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(
            walletService: walletService,
            storage: storage,
            fileName: "WalletSolanaEmailWithStaleDeviceSigner"
        )

        try await wallet.recover()

        #expect(await wallet.needsRecovery() == false)
        #expect(walletService.addSignerCallCount == 1)
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

    @Test
    func marksTheWalletForRecoveryWhenTheTrustedKeyCannotSign() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeSolanaWallet(walletService: walletService, storage: storage)
        try await wallet.recover()
        try await wallet.useSigner(.device)
        let locator = try #require(await wallet.localDeviceSigner())
        storage.signMessageError = .signingFailed(
            operation: "Secure Enclave key reconstruction",
            underlyingError: EnclaveFailure.keyGone
        )

        await #expect(throws: SignerError.self) {
            try await wallet.makeSignRequest(for: locator.value, message: Data("m".utf8).base64EncodedString())
        }

        #expect(await wallet.needsRecovery())
    }

    private enum EnclaveFailure: Error { case keyGone }

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
