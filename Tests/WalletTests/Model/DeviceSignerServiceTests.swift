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

        try await service.register(storage: storage, signer: MockSigner())

        #expect(walletService.signTransactionCallCount == 1)
        #expect(walletService.lastSignTransactionRequest?.transactionId == "registration-tx-1")
        #expect(await storage.getKey(address: walletAddress) != nil)
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
            try await service.register(storage: storage, signer: MockSigner())
        }
        #expect(storage.deletePendingKeyCallCount == 1)
        #expect(await storage.getKey(address: walletAddress) == nil)
    }
}
