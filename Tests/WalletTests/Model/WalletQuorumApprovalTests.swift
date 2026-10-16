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

@Suite("Wallet quorum approval", .tags(.unit))
struct WalletQuorumApprovalTests {
    private func makeWallet(walletService: MockSmartWalletService) throws -> StellarWallet {
        let baseModel: WalletApiModel = try GetFromFile.getModelFrom(
            fileName: "WalletStellarQuorum",
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
        try GetFromFile.getModelFrom(fileName: "StellarTransactionAwaitingQuorum", bundle: Bundle.module)
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

    @Test func namesTheQuorumAndThrowsAwaitingQuorumApprovalWhenAMemberSends() async throws {
        let walletService = MockSmartWalletService()
        let wallet = try makeWallet(walletService: walletService)
        wallet.selectedSigner = MockSigner(email: "bob@example.com")
        walletService.transferTokenResult = try awaitingQuorum()
        walletService.fetchTransactionResult = try awaitingQuorum()

        await #expect {
            _ = try await wallet.send("CANKOZR2XAFXTUT7JX6ZPKKDNOQQ2XS5RGVC6ZU57VLDNDYRJPXUK2SJ", "stellar:usdc", 1)
        } throws: { error in
            guard case .awaitingQuorumApproval(let transactionId) = error as? TransactionError else { return false }
            return transactionId == "cb99f2e5-e859-4cf3-88d8-f3c89f602d27"
        }
        #expect(walletService.transferTokenLastRequest?.signer == QUORUM.value)
    }

    @Test func acceptsAQuorumMemberAsTheActiveSigner() async throws {
        let wallet = try makeWallet(walletService: MockSmartWalletService())

        try await wallet.useSigner(.phone("+14155552671"))

        #expect(await wallet.selectedSigner?.locator == .phone("+14155552671"))
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
