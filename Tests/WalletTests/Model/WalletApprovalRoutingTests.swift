//
//  WalletApprovalRoutingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/09/26.
//

import DeviceSigner
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let ADMIN_LOCATOR = "email:mock@example.com"
private let STALE_DEVICE_LOCATOR =
    "device:BC7k2LhzqCHurW97oXe/9YKI77h80kUwPy8pY2ot+7CWficNoWbwfHddNq4Itg304yMMpDCyHgZPxBJ0KH7Y9qc="

@Suite("Wallet Approval Routing", .tags(.unit))
struct WalletApprovalRoutingTests {
    private let walletService = MockSmartWalletService()
    private let storage = MockDeviceSignerKeyStorage()
    private let adminSigner = MockSigner()

    private func makeWallet(withDeviceStorage: Bool = true) throws -> EVMWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: "WalletEVMApiKey", bundle: Bundle.module)
        walletService.getWalletResult = baseModel
        adminSigner.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "admin-signature")]
        return try EVMWallet(
            smartWalletService: walletService,
            signer: adminSigner,
            baseModel: baseModel,
            evmChain: .polygon,
            deviceSignerKeyStorage: withDeviceStorage ? storage : nil
        )
    }

    @Test func routesADeviceLocatorToTheDeviceSigner() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        let request = try await wallet.makeSignRequest(for: "device:\(publicKeyBase64)", message: "approval-message")

        #expect(try #require(request.approvals.first?.device).0 == "device:\(publicKeyBase64)")
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func signsAStaleDeviceLocatorWithTheCurrentKey() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        let request = try await wallet.makeSignRequest(for: STALE_DEVICE_LOCATOR, message: "approval-message")

        let (signer, signature) = try #require(request.approvals.first?.device)
        #expect(signer == "device:\(publicKeyBase64)")
        #expect((signature.r, signature.s) == ("0xr", "0xs"))
    }

    @Test(arguments: [true, false])
    func throwsKeyNotFoundForADeviceLocatorWithoutALocalKey(withDeviceStorage: Bool) async throws {
        let wallet = try makeWallet(withDeviceStorage: withDeviceStorage)

        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await wallet.makeSignRequest(for: STALE_DEVICE_LOCATOR, message: "approval-message")
        }
    }

    @Test func routesAnAdminLocatorToTheAdminSigner() async throws {
        let wallet = try makeWallet()

        let request = try await wallet.makeSignRequest(for: ADMIN_LOCATOR, message: "approval-message")

        #expect(try #require(request.approvals.first?.keypair) == (ADMIN_LOCATOR, "admin-signature"))
        #expect(adminSigner.initializeCallCount == 1)
    }

    @Test func refusesAnApprovalThatNamesASignerTheWalletDoesNotHold() async throws {
        let wallet = try makeWallet()

        await #expect(throws: SignerError.invalidSigner) {
            _ = try await wallet.makeSignRequest(for: "email:someone-else@example.com", message: "approval-message")
        }
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func usesTheSelectedSignerWhenItsLocatorMatches() async throws {
        let wallet = try makeWallet()
        let selected = MockSigner()
        selected.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "selected-signature")]
        wallet.selectedSigner = selected

        let request = try await wallet.makeSignRequest(for: ADMIN_LOCATOR, message: "approval-message")

        #expect(try #require(request.approvals.first?.keypair).1 == "selected-signature")
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func ignoresASelectedDeviceSignerForAnAdminApproval() async throws {
        let wallet = try makeWallet()
        _ = try await storage.generateKey(address: wallet.address)
        try await wallet.useSigner(.device)

        let request = try await wallet.makeSignRequest(for: ADMIN_LOCATOR, message: "approval-message")

        #expect(try #require(request.approvals.first?.keypair).0 == ADMIN_LOCATOR)
    }

    @Test func returnsNoSelectedLocatorWhenNoSignerIsSelected() async throws {
        #expect(try await makeWallet().selectedSignerLocator() == nil)
    }

    @Test(arguments: [
        { _ = try await $0.sendTransaction(to: $0.address, value: "0", data: nil) },
        { _ = try await $0.send($0.address, "polygon:usdc", 1) }
    ] as [@Sendable (EVMWallet) async throws -> Void])
    func failsToSendWhenTheSelectedDeviceKeyIsMissing(send: @Sendable (EVMWallet) async throws -> Void) async throws {
        let wallet = try makeWallet()
        _ = try await storage.generateKey(address: wallet.address)
        try await wallet.useSigner(.device)
        try await storage.deleteKey(address: wallet.address)
        storage.generateKeyError = .keyGenerationFailed

        await #expect {
            try await send(wallet)
        } throws: { error in
            guard case .transactionSigningFailed(let underlying) = error as? TransactionError else { return false }
            return underlying as? DeviceSignerError == .keyNotFound
        }
    }
}

private extension SignRequestApi.Approval {
    var keypair: (String, String)? {
        guard case let .keypair(signer, signature) = self else { return nil }
        return (signer, signature)
    }

    var device: (String, DeviceSignature)? {
        guard case let .device(signer, signature) = self else { return nil }
        return (signer, signature)
    }
}
