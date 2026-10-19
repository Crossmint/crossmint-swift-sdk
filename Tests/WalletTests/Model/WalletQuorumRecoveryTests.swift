//
//  WalletQuorumRecoveryTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintCommonTypes
import Foundation
import Testing
import TestsUtils

@testable import Wallet

private let QUORUM = SignerLocator.quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14")

private func loadFixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
    return try Data(contentsOf: url)
}

private struct SentRecoveryConfig: Decodable {
    struct Method: Decodable {
        let type: String
        let threshold: Int?
        let members: [Member]?
    }

    struct Member: Decodable {
        let type: String
        let email: String?
    }

    let adminSigner: Method?
    let recoveryMethods: [Method]?
}

@Suite("Wallet creation with a quorum", .tags(.unit))
struct QuorumWalletCreationTests {
    private let walletService = MockSmartWalletService()

    private func makeWallets() -> DefaultCrossmintWallets {
        DefaultCrossmintWallets(
            service: walletService,
            secureWalletStorage: StubSecureWalletStorage(),
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )
    }

    @Test func sendsTheQuorumAsTheOnlyRecoveryMethod() async throws {
        walletService.createWalletFixture = try loadFixture("WalletStellarQuorum")
        let quorum = QuorumConfig(
            threshold: 2,
            members: [MockSigner(email: "alice@example.com"), MockSigner(email: "bob@example.com")]
        )

        _ = try await makeWallets().createWallet(chain: Chain("stellar"), quorum: quorum, signers: [], options: nil)

        let body = try JSONEncoder().encode(try #require(walletService.lastCreateWalletParams?.config))
        let config = try JSONDecoder().decode(SentRecoveryConfig.self, from: body)
        let methods = try #require(config.recoveryMethods)
        #expect(config.adminSigner == nil)
        #expect(methods.count == 1)
        #expect(methods[0].type == "quorum")
        #expect(methods[0].threshold == 2)
        #expect(methods[0].members?.map(\.email) == ["alice@example.com", "bob@example.com"])
    }

    @Test func initializesEveryMemberAndActivatesTheFirstOne() async throws {
        walletService.createWalletFixture = try loadFixture("WalletStellarQuorum")
        let alice = MockSigner(email: "alice@example.com")
        let bob = MockSigner(email: "bob@example.com")

        let wallet = try await makeWallets().createWallet(
            chain: Chain("stellar"),
            quorum: QuorumConfig(threshold: 2, members: [alice, bob]),
            signers: [],
            options: nil
        )

        #expect(alice.initializeCallCount == 1)
        #expect(bob.initializeCallCount == 1)
        #expect(wallet.signer as? MockSigner === alice)
    }

    @Test func leavesAQuorumWithAPasskeyMemberOnSolanaToCrossmint() throws {
        let quorum = QuorumConfig(
            threshold: 2,
            members: [MockSigner(signerType: .passkey), MockSigner(email: "bob@example.com")]
        )

        let resolved = try RecoveryInput.quorum(quorum).resolved(for: Chain("solana"))

        guard case .quorum = resolved else {
            Issue.record("A quorum must stay a quorum")
            return
        }
    }

    @Test func rejectsAQuorumWithoutMembersBeforeCallingTheApi() async throws {
        await #expect {
            _ = try await makeWallets().createWallet(
                chain: Chain("stellar"),
                quorum: QuorumConfig(threshold: 1, members: []),
                signers: [],
                options: nil
            )
        } throws: { error in
            guard case .recoveryConfigRejected(.invalidConfig, _) = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.createWalletCallCount == 0)
    }
}

@Suite("Wallet quorum recovery method changes", .tags(.unit))
struct WalletQuorumRecoveryMethodChangesTests {
    private let walletService = MockSmartWalletService()

    private func makeWallet(fileName: String, signer: MockSigner?) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
        return try StellarWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            stellarChain: .stellar
        )
    }

    private func transaction(_ fileName: String) throws -> StellarTransactionApiModel {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    @Test func addsAQuorumAndReloadsTheRecoveryMethods() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        let success: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.addRecoveryMethodResult = success
        walletService.getWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
            bundle: Bundle.module
        )
        let quorum = QuorumConfig(
            threshold: 2,
            members: [MockSigner(email: "bob@example.com"), MockSigner(email: "carol@example.com")]
        )

        try await wallet.addRecoveryMethod(quorum: quorum)

        let sent = try #require(walletService.lastAddRecoveryMethod as? QuorumSignerInput)
        #expect(sent.threshold == 2)
        #expect(sent.members.map(\.locator) == ["email:bob@example.com", "email:carol@example.com"])
        #expect(walletService.lastAddRecoveryMethodApprover == .email("alice@example.com"))
        #expect(wallet.recoveryMethods.map(\.signer.locator) == [QUORUM.value])
    }

    @Test func returnsThePendingTransactionWhenOtherQuorumMembersMustApprove() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorum", signer: nil)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")
        walletService.addRecoveryMethodResult = try transaction("StellarTransactionAwaitingQuorum")
        walletService.fetchTransactionResult = try transaction("StellarTransactionAwaitingQuorum")

        let pending = try await wallet.addRecoveryMethod(.email("dave@example.com"))

        #expect(pending.status == .awaitingApproval)
        #expect(wallet.recoveryMethods.map(\.signer.locator) == [QUORUM.value])
    }

    @Test func returnsTheAddedQuorumWhenTheWalletCannotBeReadAgain() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        let success: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.addRecoveryMethodResult = success
        walletService.getWalletError = .walletGeneric("offline")
        let quorum = QuorumConfig(
            threshold: 2,
            members: [MockSigner(email: "bob@example.com"), MockSigner(email: "carol@example.com")]
        )

        let transaction = try await wallet.addRecoveryMethod(quorum: quorum)

        #expect(transaction.status == .success)
    }

    @Test func readsTheRecoveryMethodsAgainAfterAQuorumApprovesAChange() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorum", signer: nil)
        let success: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [try transaction("StellarTransactionQuorumApproved")]
        walletService.fetchTransactionResult = success
        walletService.getWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorumThenEmail",
            bundle: Bundle.module
        )

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(wallet.recoveryMethods.map(\.signer.locator) == [QUORUM.value, "email:carol@example.com"])
    }

    @Test func rejectsAddingAQuorumWithoutMembersBeforeCallingTheApi() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )

        await #expect {
            try await wallet.addRecoveryMethod(quorum: QuorumConfig(threshold: 1, members: []))
        } throws: { error in
            guard case .recoveryConfigRejected(.invalidConfig, _) = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.addRecoveryMethodCallCount == 0)
    }

    @Test func reportsACancelledPasskeyMemberWhenAddingAQuorum() async throws {
        let wallet = try makeWallet(
            fileName: "WalletStellarRecoveryMethods",
            signer: MockSigner(email: "alice@example.com")
        )
        let passkey = MockSigner(signerType: .passkey)
        passkey.initializeError = .passkey(.cancelled)

        await #expect {
            try await wallet.addRecoveryMethod(
                quorum: QuorumConfig(threshold: 2, members: [passkey, MockSigner(email: "bob@example.com")])
            )
        } throws: { error in
            guard case .walletGeneric(let message) = error as? WalletError else { return false }
            return message == "Passkey registration was cancelled"
        }
    }

    @Test func clearsTheSelectedApproverWhenAnApprovedChangeRemovesIt() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorumThenEmail", signer: nil)
        try await wallet.useRecoveryMethod(.email("alice@example.com"))
        let success: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [try transaction("StellarTransactionQuorumApproved")]
        walletService.fetchTransactionResult = success
        walletService.getWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletStellarRecoveryMethods",
            bundle: Bundle.module
        )

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(wallet.selectedRecoveryMethod == nil)
    }

    @Test func keepsAQuorumWhoseRemovalWaitsOnOtherMembers() async throws {
        let wallet = try makeWallet(fileName: "WalletStellarQuorum", signer: nil)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")
        walletService.removeRecoveryMethodResult = try transaction("StellarTransactionAwaitingQuorum")
        walletService.fetchTransactionResult = try transaction("StellarTransactionAwaitingQuorum")

        let pending = try await wallet.removeRecoveryMethod(locator: QUORUM)

        #expect(pending.status == .awaitingApproval)
        #expect(walletService.lastRemoveRecoveryMethodLocator == QUORUM)
        #expect(wallet.recoveryMethods.map(\.signer.locator) == [QUORUM.value])
    }
}
