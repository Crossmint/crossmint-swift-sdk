//
//  WalletPendingDeviceKeyTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/10/26.
//

import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let PENDING_TRANSACTION_ID = "cb99f2e5-e859-4cf3-88d8-f3c89f602d27"

@Suite("Wallet pending device key", .tags(.unit))
struct WalletPendingDeviceKeyTests {
    private func makeWallet(
        fixture: String,
        walletService: MockSmartWalletService,
        storage: MockDeviceSignerKeyStorage
    ) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fixture, bundle: Bundle.module)
        walletService.getWalletResult = baseModel
        return try StellarWallet(
            smartWalletService: walletService,
            signer: MockSigner(email: "alice@example.com"),
            baseModel: baseModel,
            stellarChain: .stellar,
            deviceSignerKeyStorage: storage
        )
    }

    @Test func stopsRecoveringOnceTheQuorumApprovedThePendingKey() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeWallet(
            fixture: "WalletStellarQuorumThenEmail",
            walletService: walletService,
            storage: storage
        )
        let publicKey = try await storage.generateKey(address: nil)
        wallet.pendingDeviceKey = PendingDeviceKey(
            transactionId: PENDING_TRANSACTION_ID,
            publicKeyBase64: publicKey,
            storage: storage
        )
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel

        let pending = try await wallet.recover()

        #expect(pending == nil)
        #expect(walletService.addSignerCallCount == 0)
        #expect(await storage.getKey(address: wallet.address) == publicKey)
        #expect(await !wallet.needsRecovery())
    }

    @Test func resumesThePendingKeyAfterARelaunch() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let publicKey = try await storage.generateKey(address: nil)
        let wallet = try makeWallet(
            fixture: "WalletStellarQuorumPendingDevice",
            walletService: walletService,
            storage: storage
        )
        walletService.getSignerResponses = [
            SignerLocator.device(publicKey: publicKey).value: AddDelegatedSignerResponse(
                chains: nil,
                transaction: RegistrationTransaction(id: PENDING_TRANSACTION_ID, status: "awaiting-approval")
            )
        ]
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "StellarTransactionAwaitingQuorum",
            bundle: Bundle.module
        ) as StellarTransactionApiModel

        let pending = try await wallet.recover()

        #expect(pending?.id == PENDING_TRANSACTION_ID)
        #expect(walletService.addSignerCallCount == 0)
        #expect(await wallet.needsRecovery())
    }
}
