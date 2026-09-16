//
//  WalletSelectedSignerLocatorTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/09/26.
//

import CrossmintCommonTypes
import DeviceSigner
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Wallet Selected Signer Locator", .tags(.unit))
struct WalletSelectedSignerLocatorTests {
    private let walletService = MockSmartWalletService()
    private let storage = MockDeviceSignerKeyStorage()

    private func makeWallet() throws -> EVMWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletEVMApiKey",
            bundle: Bundle.module
        )
        walletService.getWalletResult = baseModel
        return try EVMWallet(
            smartWalletService: walletService,
            signer: MockSigner(),
            baseModel: baseModel,
            evmChain: .polygon,
            deviceSignerKeyStorage: storage
        )
    }

    private func makeWalletWithMissingDeviceKey() async throws -> EVMWallet {
        let wallet = try makeWallet()
        _ = try await storage.generateKey(address: wallet.address)
        try await wallet.useSigner(.device)
        try await storage.deleteKey(address: wallet.address)
        storage.generateKeyError = .keyGenerationFailed
        return wallet
    }

    private func isSigningFailure(_ error: any Error) -> Bool {
        guard case .transactionSigningFailed(let underlying) = error as? TransactionError else { return false }
        guard case .keyNotFound = underlying as? DeviceSignerError else { return false }
        return true
    }

    @Test func returnsNilWhenNoSignerIsSelected() async throws {
        let wallet = try makeWallet()

        #expect(try await wallet.selectedSignerLocator() == nil)
    }

    @Test func failsAnEVMSendWhenTheSelectedDeviceKeyIsMissing() async throws {
        let wallet = try await makeWalletWithMissingDeviceKey()

        await #expect {
            try await wallet.sendTransaction(to: wallet.address, value: "0", data: nil)
        } throws: { isSigningFailure($0) }
        #expect(walletService.createTransactionCallCount == 0)
    }

    @Test func failsATransferWhenTheSelectedDeviceKeyIsMissing() async throws {
        let wallet = try await makeWalletWithMissingDeviceKey()

        await #expect {
            try await wallet.send(wallet.address, "polygon:usdc", 1)
        } throws: { isSigningFailure($0) }
        #expect(walletService.transferTokenCallCount == 0)
    }
}
