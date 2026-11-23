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

    private func makeTwoQuorumWallet(walletService: MockSmartWalletService) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarTwoQuorums",
            bundle: Bundle.module
        )
        walletService.getWalletResult = baseModel
        return try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
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
        member.approvalsResult = [.keypair(signer: "email:bob@example.com", signature: "bob-signature")]
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
        carol.approvalsResult = [.keypair(signer: "email:carol@example.com", signature: "carol-signature")]
        let wallet = try makeWallet(walletService: walletService, signer: carol)
        let bob = MockSigner(email: "bob@example.com")
        bob.approvalsResult = [.keypair(signer: "email:bob@example.com", signature: "bob-signature")]
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
        #expect(summary.hash == nil)
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

    @Test func createsATransferForTheQuorumWithoutSigningForTheHeldMember() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.transferTokenResult = try awaitingQuorum()

        let summary = try await wallet.send(RECIPIENT, "stellar:usdc", 1)

        #expect(summary.transactionID == "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        #expect(summary.hash == nil)
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func createsARawTransactionForTheQuorumWithoutSigningForTheHeldMember() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.createTransactionResult = try awaitingQuorum()

        let summary = try await wallet.sendTransaction(transaction: "AAAA")

        #expect(summary.hash == nil)
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func namesTheQuorumAsApproverWhenAPasskeyMemberIsTheSelectedRecoveryMethod() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorumWithPasskey",
            bundle: Bundle.module
        )
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
        walletService.removeRecoveryMethodResult = try awaitingQuorum()
        walletService.fetchTransactionResults = [try awaitingQuorum()]
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel

        try await wallet.useRecoveryMethod(
            .passkey(name: "alice", host: "example.com", id: "v-Qxh--c2nOkUyBYJHRaXCwSOJw")
        )
        _ = try? await wallet.removeRecoveryMethod(locator: .email("carol@example.com"))

        #expect(walletService.lastRemoveRecoveryMethodApprover == QUORUM)
    }

    @Test func namesTheQuorumAsApproverWhenTheActiveSignerIsAMember() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorumWithPasskey",
            bundle: Bundle.module
        )
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
        wallet.selectedSigner = MockSigner(email: "alice@example.com")
        walletService.removeRecoveryMethodResult = try awaitingQuorum()
        walletService.fetchTransactionResults = [try awaitingQuorum()]
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel

        _ = try? await wallet.removeRecoveryMethod(locator: .email("carol@example.com"))

        #expect(walletService.lastRemoveRecoveryMethodApprover == QUORUM)
    }

    @Test func approvesForTheQuorumThatTheChangeNames() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeTwoQuorumWallet(walletService: walletService)
        let second = SignerLocator.quorum(id: "2b7d1c0e-6a5f-4b3c-9d8e-7f6a5b4c3d2e")
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        )
        walletService.fetchTransactionResult = try awaitingQuorum()
        try await wallet.useRecoveryMethod(.email("bob@example.com"))

        try await wallet.addSigner(.email("dave@example.com"), signer: second, prepareOnly: true)

        #expect(walletService.lastAddSignerApprover == second)
    }

    @Test func selectsAPasskeyThatTwoQuorumsShareWithoutItsId() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarTwoQuorumsSharedPasskey",
            bundle: Bundle.module
        )
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar
        )
        let second = SignerLocator.quorum(id: "2b7d1c0e-6a5f-4b3c-9d8e-7f6a5b4c3d2e")
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        )
        walletService.fetchTransactionResult = try awaitingQuorum()

        try await wallet.useRecoveryMethod(.passkey(name: "alice", host: "example.com"))
        try await wallet.addSigner(.email("dave@example.com"), signer: second, prepareOnly: true)

        #expect(walletService.lastAddSignerApprover == second)
    }

    @Test func rejectsAChangeByAMemberOfSeveralQuorumsWhenTheChangeNamesNoSigner() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeTwoQuorumWallet(walletService: walletService)
        try await wallet.useRecoveryMethod(.email("bob@example.com"))

        await #expect {
            try await wallet.addSigner(.email("dave@example.com"), prepareOnly: true)
        } throws: { error in
            guard case .quorumSelectionAmbiguous = error as? WalletError else { return false }
            return true
        }
        #expect(walletService.addSignerCallCount == 0)
    }

    @Test func returnsThePendingDeviceSignerWithoutApprovingItForTheQuorum() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorumThenEmail",
            bundle: Bundle.module
        )
        walletService.getWalletResult = baseModel
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        )
        walletService.fetchTransactionResult = try awaitingQuorum()
        let member = MockSigner(email: "alice@example.com")
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: member,
            baseModel: baseModel,
            stellarChain: .stellar,
            deviceSignerKeyStorage: MockDeviceSignerKeyStorage()
        )

        let pending = try await wallet.recover()

        #expect(pending?.status == .awaitingApproval)
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
        #expect(await wallet.needsRecovery())
    }

    @Test(arguments: [QUORUM, nil])
    func createsASignerAdditionForTheQuorumWithoutApprovingIt(signer: SignerLocator?) async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.addSignerResult = AddDelegatedSignerResponse(
            chains: nil,
            transaction: RegistrationTransaction(id: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        )
        walletService.fetchTransactionResult = try awaitingQuorum()

        let pending = try await wallet.addSigner(.email("dave@example.com"), signer: signer)

        #expect(pending?.id == "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func createsASignerRemovalForTheQuorumWithoutApprovingIt() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        let member = MockSigner(email: "bob@example.com")
        wallet.selectedSigner = member
        walletService.removeSignerResult = try awaitingQuorum()

        let pending = try await wallet.removeSigner(locator: .email("dave@example.com"), signer: QUORUM)

        #expect(pending.status == .awaitingApproval)
        #expect(member.signedMessages.isEmpty)
        #expect(walletService.signTransactionCallCount == 0)
    }

    @Test func forgetsTheKeyOfThisDeviceOnceTheQuorumApprovesItsRemoval() async throws {
        let walletService = MockSmartWalletService()
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorumPendingDevice",
            bundle: Bundle.module
        )
        let storage = MockDeviceSignerKeyStorage()
        _ = try await storage.generateKey(address: baseModel.address)
        let wallet = try StellarWallet(
            smartWalletService: walletService,
            signer: nil,
            baseModel: baseModel,
            stellarChain: .stellar,
            deviceSignerKeyStorage: storage
        )
        walletService.getWalletResult = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
            bundle: Bundle.module
        )
        walletService.fetchTransactionResults = [try transaction("StellarTransactionQuorumApproved")]
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel

        _ = try await wallet.approve(transactionId: "cb99f2e5-e859-4cf3-88d8-f3c89f602d27")

        #expect(await storage.getKey(address: wallet.address) == nil)
    }

    @Test func activatesThePendingDeviceSignerOnceTheQuorumApproves() async throws {
        let walletService = MockSmartWalletService()
        let storage = MockDeviceSignerKeyStorage()
        let wallet = try makeWallet(walletService: walletService)
        walletService.fetchTransactionResult = try GetFromFile.getModelFrom(
            fileName: "RemoveSignerTransactionSuccess",
            bundle: Bundle.module
        ) as SolanaTransactionApiModel
        wallet.pendingDeviceKey = PendingDeviceKey(
            transactionId: "1d9e2f88-4c1b-4b6e-9a3f-6f9d1f2a7c55",
            publicKeyBase64: "device-key",
            storage: storage
        )

        _ = try await wallet.approve(transactionId: "1d9e2f88-4c1b-4b6e-9a3f-6f9d1f2a7c55")

        #expect(await storage.getKey(address: wallet.address) == "device-key")
        #expect(wallet.pendingDeviceKey == nil)
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

    private func makeTransferService(errorBody: Data) throws -> DefaultTransferService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.invalidStatusCode(422, errorBody)
            })
        )
        return DefaultTransferService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
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

    @Test func throwsTransactionCancelledWhenCrossmintCancelledTheTransaction() async throws {
        let body = Data(#"{"message": "The transaction was cancelled.", "code": "TRANSACTION_CANCELLED"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.signTransaction(signRequest())
        } throws: { error in
            guard case .transactionCancelled(let message) = error as? TransactionError else { return false }
            return message == "The transaction was cancelled."
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

    @Test func throwsSignerIsQuorumMemberWhenAMemberCreatesATransfer() async throws {
        let body = Data(#"{"message": "Signer is a quorum member.", "code": "SIGNER_IS_QUORUM_MEMBER"}"#.utf8)
        let service = try makeTransferService(errorBody: body)
        let request = TransferTokenRequest(
            chainType: .stellar,
            tokenLocator: "stellar:usdc",
            recipient: RECIPIENT,
            amount: "1",
            signer: "email:bob@example.com",
            idempotencyKey: nil
        )

        await #expect {
            _ = try await service.transferToken(request)
        } throws: { error in
            guard case .signerIsQuorumMember = error as? TransactionError else { return false }
            return true
        }
    }
}
