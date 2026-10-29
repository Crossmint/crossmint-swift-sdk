//
//  WalletQuorumApprovalTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 16/10/26.
//

import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Http
@testable import Wallet

private let QUORUM = SignerLocator.quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14")
private let RECIPIENT = "CANKOZR2XAFXTUT7JX6ZPKKDNOQQ2XS5RGVC6ZU57VLDNDYRJPXUK2SJ"

@Suite("Wallet quorum approval", .tags(.unit))
struct WalletQuorumApprovalTests {
    private func makeWallet(
        walletService: MockSmartWalletService,
        signer: MockSigner? = nil
    ) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
            bundle: Bundle.module
        )
        walletService.getWalletResult = baseModel
        return try StellarWallet(
            smartWalletService: walletService,
            signer: signer,
            baseModel: baseModel,
            stellarChain: .stellar
        )
    }

    private func awaitingQuorum() throws -> StellarTransactionApiModel {
        try transaction("StellarTransactionAwaitingQuorum")
    }

    private func transaction(_ fileName: String) throws -> StellarTransactionApiModel {
        try GetFromFile.getModelFrom(fileName: fileName, bundle: Bundle.module)
    }

    private func fixtureData(_ fileName: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: fileName, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func signsTheMessageOfTheMemberThisDeviceHolds() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.fetchTransactionResult = try awaitingQuorum()

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(member.signedMessages == ["bob-message"])
        #expect(walletService.signTransactionCallCount == 1)
    }

    @Test func returnsWhileOtherMembersMustStillApprove() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")
        walletService.fetchTransactionResult = try awaitingQuorum()

        let transaction = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(transaction.status == .awaitingApproval)
        #expect(transaction.approvals?.quorums.first?.remaining == 1)
    }

    @Test func skipsTheMembersThisDeviceDoesNotHold() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let outsider = MockSigner(email: "carol@example.com")
        wallet.selectedSigner = outsider
        walletService.fetchTransactionResult = try awaitingQuorum()

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(outsider.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func signsNothingForAQuorumThatAlreadyApproved() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        let success: SolanaTransactionApiModel = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [try transaction("StellarTransactionQuorumApproved")]
        walletService.fetchTransactionResult = success

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func signsEveryHeldMemberInOneRequest() async throws {
        let walletService = MockSmartWalletService()
        let carol = MockSigner(email: "carol@example.com")
        let wallet = try makeWallet(walletService: walletService, signer: carol)
        let bob = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = bob
        walletService.fetchTransactionResult = try transaction("StellarTransactionAwaitingOneOfTwoMembers")

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(bob.signedMessages == ["bob-message"])
        #expect(carol.signedMessages == ["carol-message"])
        #expect(walletService.signTransactionCallCount == 1)
    }

    @Test func preparesATransferForTheQuorumWithoutSigningIt() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.transferTokenResult = try awaitingQuorum()
        try await wallet.useSigner(.email("bob@example.com"))

        let summary = try await wallet.send(RECIPIENT, "stellar:usdc", 1, prepareOnly: true)

        #expect(summary.transactionID == "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        #expect(summary.status == .awaitingApproval)
        #expect(walletService.transferTokenLastRequest?.signer == QUORUM.value)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func preparesARawTransactionWithoutSigningIt() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")
        walletService.createTransactionResult = try awaitingQuorum()

        let summary = try await wallet.sendTransaction(transaction: "AAAA", prepareOnly: true)

        #expect(summary.transactionID == "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        #expect(summary.hash == nil)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func returnsAPendingSummaryWhenOtherMembersMustApprove() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.transferTokenResult = try awaitingQuorum()
        walletService.fetchTransactionResult = try awaitingQuorum()

        let summary = try await wallet.send(RECIPIENT, "stellar:usdc", 1)

        #expect(summary.status == .awaitingApproval)
        #expect(summary.hash == nil)
        #expect(member.signedMessages == ["bob-message"])
    }

    @Test func actsForTheQuorumWhenTheSignerIsOnlyAMember() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.transferTokenResult = try awaitingQuorum()
        try await wallet.useSigner(.phone("+14155552671"))

        _ = try await wallet.send(RECIPIENT, "stellar:usdc", 1, prepareOnly: true)

        #expect(walletService.transferTokenLastRequest?.signer == QUORUM.value)
    }

    @Test func actsAsItselfWhenTheMemberIsAlsoASigner() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.getWalletResult = nil
        walletService.getWalletFixture = try fixtureData("WalletStellarQuorum")
        walletService.getWalletSignerLocators = ["email:alice@example.com"]
        walletService.transferTokenResult = try awaitingQuorum()
        try await wallet.useSigner(.email("alice@example.com"))

        _ = try await wallet.send(RECIPIENT, "stellar:usdc", 1, prepareOnly: true)

        #expect(walletService.transferTokenLastRequest?.signer == "email:alice@example.com")
    }

    @Test func actsForTheQuorumThatTheCallNames() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        walletService.getWalletResult = nil
        walletService.getWalletFixture = try fixtureData("WalletStellarQuorum")
        walletService.getWalletSignerLocators = ["email:alice@example.com"]
        walletService.transferTokenResult = try awaitingQuorum()
        try await wallet.useSigner(.email("alice@example.com"))

        _ = try await wallet.send(RECIPIENT, "stellar:usdc", 1, signer: QUORUM, prepareOnly: true)

        #expect(walletService.transferTokenLastRequest?.signer == QUORUM.value)
    }

    @Test func rejectsAMemberOfSeveralQuorumsWhenTheCallNamesNoSigner() async throws {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarTwoQuorums",
            bundle: Bundle.module
        )
        let walletService = MockSmartWalletService()
        walletService.getWalletResult = baseModel
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
        try await wallet.useSigner(.email("bob@example.com"))

        await #expect {
            _ = try await wallet.send(RECIPIENT, "stellar:usdc", 1, prepareOnly: true)
        } throws: { error in
            guard case .quorumSelectionAmbiguous(let quorums) = error as? TransactionError else { return false }
            return quorums.count == 2
        }
        #expect(walletService.transferTokenCallCount == 0)
    }
}

@Suite("Quorum transaction errors", .tags(.unit))
struct QuorumTransactionErrorTests {
    private func makeService(errorBody: Data) throws -> DefaultTransactionService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.invalidStatusCode(422, errorBody)
            })
        )
        return DefaultTransactionService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func signRequest() -> SignRequest {
        SignRequest(transactionId: "tx", apiRequest: SignRequestApi(approvals: []), chainType: .stellar)
    }

    @Test func throwsTransactionExpiredWhenTheApprovalWindowClosed() async throws {
        let body = Data(#"{"message": "The transaction expired.", "code": "TRANSACTION_EXPIRED"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.signTransaction(signRequest())
        } throws: { error in
            guard case .transactionExpired(let message) = error as? TransactionError else { return false }
            return message == "The transaction expired."
        }
    }

    @Test func throwsSignerIsQuorumMemberWhenAMemberCreatesATransaction() async throws {
        let body = Data(#"{"message": "Signer is a quorum member.", "code": "SIGNER_IS_QUORUM_MEMBER"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.signTransaction(signRequest())
        } throws: { error in
            guard case .signerIsQuorumMember = error as? TransactionError else { return false }
            return true
        }
    }
}
