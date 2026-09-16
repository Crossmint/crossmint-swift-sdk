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

    private func makeWallet(withDeviceStorage: Bool = true) throws -> SolanaWallet {
        let fixtureUrl = try #require(Bundle.module.url(forResource: "WalletSolanaEmail", withExtension: "json"))
        walletService.getWalletFixture = try Data(contentsOf: fixtureUrl)
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "SolanaSignerRegistrationAwaitingApproval",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel
        adminSigner.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "admin-signature")]
        return try SolanaWallet(
            smartWalletService: walletService,
            signer: adminSigner,
            baseModel: try GetFromFile.getModelFrom(fileName: "WalletSolanaEmail", bundle: Bundle.module),
            solanaChain: .solana,
            onTransactionStart: nil,
            deviceSignerKeyStorage: withDeviceStorage ? storage : nil
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
            approvals: .init(pending: [.init(signer: locator, message: "approval-message")], submitted: []),
            error: nil
        )
    }

    private func submittedApproval() throws -> SignRequestApi.Approval {
        try #require(walletService.lastSignTransactionRequest?.apiRequest.approvals.first)
    }

    @Test func routesDeviceLocatorToTheDeviceSigner() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: "device:\(publicKeyBase64)"))

        #expect(try #require(submittedApproval().device).0 == "device:\(publicKeyBase64)")
        #expect(adminSigner.initializeCallCount == 0)
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

        #expect(try #require(submittedApproval().keypair) == (ADMIN_LOCATOR, "admin-signature"))
        #expect(adminSigner.initializeCallCount == 1)
    }

    @Test func usesTheSelectedSignerWhenItsLocatorMatches() async throws {
        let wallet = try makeWallet()
        let selected = MockSigner()
        selected.approvalsResult = [.keypair(signer: ADMIN_LOCATOR, signature: "selected-signature")]
        wallet.selectedSigner = selected

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: ADMIN_LOCATOR))

        #expect(try #require(submittedApproval().keypair).1 == "selected-signature")
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func ignoresASelectedDeviceSignerForAnAdminApproval() async throws {
        let wallet = try makeWallet()
        _ = try await storage.generateKey(address: wallet.address)
        try await wallet.useSigner(.device)

        _ = try await wallet.signAndPollWhilePending(transaction(pendingFor: ADMIN_LOCATOR))

        #expect(try #require(submittedApproval().keypair).0 == ADMIN_LOCATOR)
    }

    @Test func buildsADeviceApprovalForAStaleDeviceLocator() async throws {
        let wallet = try makeWallet()
        let publicKeyBase64 = try await storage.generateKey(address: wallet.address)

        let request = try await wallet.makeSignRequest(for: STALE_DEVICE_LOCATOR, message: "approval-message")

        let (signer, signature) = try #require(request.approvals.first?.device)
        #expect(signer == "device:\(publicKeyBase64)")
        #expect((signature.r, signature.s) == ("0xr", "0xs"))
        #expect(adminSigner.initializeCallCount == 0)
    }

    @Test func fallsBackToTheAdminSignerForAnUnrecognisedLocator() async throws {
        let wallet = try makeWallet()

        let request = try await wallet.makeSignRequest(for: "not-a-locator", message: "approval-message")

        #expect(try #require(request.approvals.first?.keypair).0 == ADMIN_LOCATOR)
    }

    @Test func throwsKeyNotFoundForADeviceLocatorWithoutDeviceStorage() async throws {
        let wallet = try makeWallet(withDeviceStorage: false)

        await #expect(throws: SignerError.device(.keyNotFound)) {
            try await wallet.makeSignRequest(for: STALE_DEVICE_LOCATOR, message: "approval-message")
        }
    }
}
