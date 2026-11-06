import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Device Signer Registration", .tags(.unit))
struct DeviceSignerServiceTests {
    private let walletAddress = "7ZN9rAofFVVP1WKqfKozsVWQYcDj2u9juYyRkrKUVR8Y"

    private func makeSolanaService(walletService: MockSmartWalletService) -> DeviceSignerService {
        DeviceSignerService(
            smartWalletService: walletService,
            chainType: .solana,
            chainName: "solana",
            address: walletAddress
        )
    }

    @Test
    func approvesTransactionShapedRegistrationAndMapsTheKey() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )
        let registrationTransaction: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SolanaSignerRegistrationAwaitingApproval",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResult = registrationTransaction
        let storage = MockDeviceSignerKeyStorage()
        let service = makeSolanaService(walletService: walletService)

        try await service.register(
            storage: storage,
            approver: RecoveryApprover(signer: MockSigner(), locator: nil)
        )

        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.lastSignTransactionRequest?.transactionId == "registration-tx-1")
        #expect(await storage.getKey(address: walletAddress) != nil)
    }

    @Test
    func sendsDevicePublicKeyAndNameWhenRegistering() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let service = makeSolanaService(walletService: walletService)

        try await service.register(
            storage: storage,
            approver: RecoveryApprover(signer: MockSigner(), locator: nil)
        )

        let registeredSigner = try #require(walletService.lastAddSignerEntry?.signer)
        let publicKeyBase64 = try #require(await storage.getKey(address: walletAddress))
        let expectedKey = try #require(DevicePublicKey(publicKeyBase64: publicKeyBase64))
        #expect(registeredSigner == .device(publicKey: expectedKey, name: "Test Device"))
    }

    @Test
    func wipesThePendingKeyWhenTheTransactionApprovalFails() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )
        let storage = MockDeviceSignerKeyStorage()
        let service = makeSolanaService(walletService: walletService)

        await #expect(throws: WalletError.self) {
            try await service.register(
            storage: storage,
            approver: RecoveryApprover(signer: MockSigner(), locator: nil)
        )
        }
        #expect(storage.deletePendingKeyCallCount == 1)
        #expect(await storage.getKey(address: walletAddress) == nil)
    }

    @Test
    func keepsThePendingKeyWhenPreparingTheRegistration() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )
        let storage = MockDeviceSignerKeyStorage()
        let service = makeSolanaService(walletService: walletService)

        let pending = try await service.register(
            storage: storage,
            approver: RecoveryApprover(signer: MockSigner(email: "carol@example.com"), locator: nil),
            prepareOnly: true
        )

        #expect(pending?.transactionId == "registration-tx-1")
        #expect(walletService.signTransactionCallCount == 0)
        #expect(storage.deletePendingKeyCallCount == 0)
        #expect(await storage.getKey(address: walletAddress) == nil)
    }

    @Test
    func keepsThePendingKeyWithoutApprovingItWhenAQuorumApproves() async throws {
        let walletService = MockSmartWalletService()
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "registration-tx-1")
        )
        let storage = MockDeviceSignerKeyStorage()
        let member = MockSigner(email: "bob@example.com")
        let service = makeSolanaService(walletService: walletService)

        let pending = try await service.register(
            storage: storage,
            approver: RecoveryApprover(signer: member, locator: .quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"))
        )

        #expect(pending?.transactionId == "registration-tx-1")
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
        #expect(await storage.getKey(address: walletAddress) == nil)
    }
}
