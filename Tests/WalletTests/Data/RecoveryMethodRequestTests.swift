//
//  RecoveryMethodRequestTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintCommonTypes
import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Wallet

@Suite("Recovery method requests", .tags(.unit))
struct RecoveryMethodRequestTests {
    private let router = HTTPFixtureRouter()

    private func makeService(fixture: String) throws -> DefaultWalletService {
        let url = try #require(Bundle.module.url(forResource: fixture, withExtension: "json"))
        router.respond(body: try Data(contentsOf: url))
        return try makeService()
    }

    private func makeService(status: Int, body: String) throws -> DefaultWalletService {
        router.respond(status: status, json: body)
        return try makeService()
    }

    private func makeService() throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: router.client
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    @Test func postsTheRecoveryMethodAndTheApprover() async throws {
        let service = try makeService(fixture: "AddRecoveryMethodResponse")

        let transaction = try await service.addRecoveryMethod(
            PhoneSignerData(phone: "+14155552671"),
            chainType: .solana,
            chainName: "solana",
            approver: .email("alice@example.com")
        )

        let request = try #require(router.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path.hasSuffix("/2025-06-09/wallets/me:solana/recovery-methods") == true)
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["approver"] as? String == "email:alice@example.com")
        #expect(json["chain"] == nil)
        let method = try #require(json["recoveryMethods"] as? [String: String])
        #expect(method == ["type": "phone", "phone": "+14155552671"])
        #expect(transaction.toDomain().id == "recovery-tx-1")
    }

    @Test func decodesTheTransactionOfASuccessfulRemoval() async throws {
        let service = try makeService(fixture: "RemoveSignerTransactionSuccess")

        let transaction = try await service.removeRecoveryMethod(
            .phone("+14155552671"),
            chainType: .solana,
            chainName: "solana",
            approver: .email("alice@example.com")
        )

        #expect(transaction.toDomain().status == .success)
    }

    @Test func deletesTheEncodedLocatorAndMapsTheLastRecoverySignerCode() async throws {
        let body = #"{"message": "Cannot remove the last recovery signer", "code": "LAST_RECOVERY_SIGNER"}"#
        let service = try makeService(status: 400, body: body)

        let error = await #expect(throws: WalletError.self) {
            _ = try await service.removeRecoveryMethod(
                .phone("+14155552671"),
                chainType: .solana,
                chainName: "solana",
                approver: .email("alice@example.com")
            )
        }

        let url = try #require(router.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(router.lastRequest?.httpMethod == "DELETE")
        #expect(components.percentEncodedPath.hasSuffix(
            "/2025-06-09/wallets/me:solana/recovery-methods/phone:%2B14155552671"
        ))
        #expect(components.queryItems == [URLQueryItem(name: "approver", value: "email:alice@example.com")])
        #expect(error?.code == "LAST_RECOVERY_SIGNER")
        #expect(error?.message == "Cannot remove the last recovery signer")
    }

    @Test func postsTheApprovingMembersOfTheQuorum() async throws {
        let service = try makeService(fixture: "AddRecoveryMethodResponse")

        _ = try await service.addRecoveryMethod(
            PhoneSignerData(phone: "+14155552671"),
            chainType: .solana,
            chainName: "solana",
            approval: SignerChangeApproval(
                approver: .quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"),
                approvingMembers: [.email("alice@example.com"), .email("bob@example.com")]
            )
        )

        let body = try #require(router.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["approvingMembers"] as? [String] == ["email:alice@example.com", "email:bob@example.com"])
    }

    @Test func repeatsEachApprovingMemberInTheQueryOfARemoval() async throws {
        let service = try makeService(fixture: "RemoveSignerTransactionSuccess")

        _ = try await service.removeRecoveryMethod(
            .phone("+14155552671"),
            chainType: .solana,
            chainName: "solana",
            approval: SignerChangeApproval(
                approver: .quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"),
                approvingMembers: [.email("alice@example.com"), .email("bob@example.com")]
            )
        )

        let url = try #require(router.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [
            URLQueryItem(name: "approver", value: "quorum:9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"),
            URLQueryItem(name: "approvingMembers", value: "email:alice@example.com"),
            URLQueryItem(name: "approvingMembers", value: "email:bob@example.com")
        ])
    }

    @Test func repeatsEachApprovingMemberInTheQueryOfASignerRemoval() async throws {
        let service = try makeService(fixture: "RemoveSignerTransactionSuccess")

        _ = try await service.removeSigner(
            "email:dave@example.com",
            chainType: .solana,
            chainName: "solana",
            approval: SignerChangeApproval(
                approver: .quorum(id: "9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"),
                approvingMembers: [.email("alice@example.com"), .email("bob@example.com")]
            )
        )

        let url = try #require(router.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [
            URLQueryItem(name: "approver", value: "quorum:9f2c6a1e-4b7d-4c3a-9e51-2d8f0b6c7a14"),
            URLQueryItem(name: "approvingMembers", value: "email:alice@example.com"),
            URLQueryItem(name: "approvingMembers", value: "email:bob@example.com")
        ])
    }

    @Test func namesTheChainWhenAddingOnEVM() async throws {
        let service = try makeService(fixture: "EVMAddRecoveryMethodResponse")

        let transaction = try await service.addRecoveryMethod(
            PhoneSignerData(phone: "+14155552671"),
            chainType: .evm,
            chainName: "base-sepolia",
            approver: .email("alice@example.com")
        )

        let body = try #require(router.lastRequest?.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["chain"] as? String == "base-sepolia")
        #expect(transaction.toDomain().id == "evm-recovery-tx-1")
    }

    @Test func namesTheChainWhenRemovingOnEVM() async throws {
        let service = try makeService(fixture: "GetTransactionResponse")

        _ = try await service.removeRecoveryMethod(
            .phone("+14155552671"),
            chainType: .evm,
            chainName: "base-sepolia",
            approver: .email("alice@example.com")
        )

        let url = try #require(router.lastRequest?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == [
            URLQueryItem(name: "approver", value: "email:alice@example.com"),
            URLQueryItem(name: "chain", value: "base-sepolia")
        ])
    }
}
