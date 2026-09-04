//
//  WalletApprovalRoutingTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 04/09/26.
//

import CrossmintCommonTypes
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

    private func makeWallet() throws -> SolanaWallet {
        let fixtureUrl = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        walletService.getWalletFixture = try Data(contentsOf: fixtureUrl)
        let signedTransaction: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "SolanaSignerRegistrationAwaitingApproval",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResult = signedTransaction
        adminSigner.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "admin-signature")]
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletSolanaEmail",
            bundle: Bundle.module
        )
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: adminSigner,
            baseModel: baseModel,
            solanaChain: .solana,
            onTransactionStart: nil,
            deviceSignerKeyStorage: storage
        )
    }

    private func transaction(pendingFor locator: String) -> Transaction {
        Transaction(
            id: "tx-1",
            status: .success,
            onChain: .init(),
            params: .init(signer: locator),
            walletType: .smart,
            createdAt: Date(),
            approvals: .init(
                pending: [.init(signer: locator, message: "approval-message")],
                submitted: []
            ),
            error: nil
        )
    }

    private func submittedApproval() throws -> SignRequestApi.Approval {
        let request = try #require(walletService.lastSignTransactionRequest)
        return try #require(request.apiRequest.approvals.first)
    }

    @Test func routesDeviceLocatorToTheDeviceSigner() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: "device:\(publicKeyBase64)"))

        guard case let .device(locator, _) = try submittedApproval() else {
            Issue.record("Expected a device approval")
            return
        }
        #expect(locator == "device:\(publicKeyBase64)")
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func routesStaleDeviceLocatorToTheCurrentDeviceKey() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: STALE_DEVICE_LOCATOR))

        guard case let .device(locator, _) = try submittedApproval() else {
            Issue.record("Expected a device approval")
            return
        }
        #expect(locator == "device:\(publicKeyBase64)")
    }

    @Test func failsDeviceLocatorWithoutALocalKey() async throws {
        let wallet = try makeWallet()

        await #expect {
            try await wallet.signAndPollWhilePending(transaction(pendingFor: STALE_DEVICE_LOCATOR))
        } throws: { error in
            guard case .transactionSigningFailed = error as? TransactionError else { return false }
            return true
        }
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func routesAdminLocatorToTheAdminSigner() async throws {
        let wallet = try makeWallet()

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: ADMIN_LOCATOR))

        guard case let .keypair(locator, signature) = try submittedApproval() else {
            Issue.record("Expected a keypair approval")
            return
        }
        #expect(locator == ADMIN_LOCATOR)
        #expect(signature == "admin-signature")
        #expect(adminSigner.initializeCallCount == 1)
    }

    @Test func usesTheSelectedSignerWhenItsLocatorMatches() async throws {
        let wallet = try makeWallet()
        let selected = MockSigner()
        selected.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "selected-signature")]
        wallet.selectedSigner = selected

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: ADMIN_LOCATOR))

        guard case let .keypair(_, signature) = try submittedApproval() else {
            Issue.record("Expected a keypair approval")
            return
        }
        #expect(signature == "selected-signature")
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func ignoresASelectedDeviceSignerForAnAdminApproval() async throws {
        let wallet = try makeWallet()
        _ = try await storage.generateKey(address: wallet.address)
        try await wallet.useSigner(.device)

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: ADMIN_LOCATOR))

        guard case let .keypair(locator, _) = try submittedApproval() else {
            Issue.record("Expected a keypair approval")
            return
        }
        #expect(locator == ADMIN_LOCATOR)
    }
}
