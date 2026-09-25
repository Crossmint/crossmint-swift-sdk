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

@testable import Http
@testable import Wallet

@Suite("Recovery method requests", .tags(.unit))
struct RecoveryMethodRequestTests {
    private func makeService(
        capturingRequestInto capturedRequest: SendableBox<URLRequest?>,
        responseBody: Data
    ) throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { request throws(NetworkError) in
                capturedRequest.value = request
                return (responseBody, URLResponse())
            })
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func fixture(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func postsTheRecoveryMethodAndTheApprover() async throws {
        let capturedRequest = SendableBox<URLRequest?>(nil)
        let service = try makeService(
            capturingRequestInto: capturedRequest,
            responseBody: try fixture("AddRecoveryMethodResponse")
        )

        let transaction = try await service.addRecoveryMethod(
            PhoneSignerData(phone: "+14155552671"),
            chainType: .solana,
            approver: .email("alice@example.com")
        )

        let request = try #require(capturedRequest.value)
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

    @Test func deletesTheEncodedLocatorWithTheApproverQuery() async throws {
        let capturedRequest = SendableBox<URLRequest?>(nil)
        let service = try makeService(
            capturingRequestInto: capturedRequest,
            responseBody: try fixture("RemoveSignerTransactionSuccess")
        )

        _ = try await service.removeRecoveryMethod(
            .phone("+14155552671"),
            chainType: .solana,
            approver: .email("alice@example.com")
        )

        let request = try #require(capturedRequest.value)
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(request.httpMethod == "DELETE")
        #expect(components.percentEncodedPath.hasSuffix(
            "/2025-06-09/wallets/me:solana/recovery-methods/phone:%2B14155552671"
        ))
        #expect(components.queryItems == [URLQueryItem(name: "approver", value: "email:alice@example.com")])
    }

    @Test func mapsTheLastRecoverySignerCode() async throws {
        let body = Data(
            #"{"error": true, "message": "Cannot remove the last recovery signer", "code": "LAST_RECOVERY_SIGNER"}"#
                .utf8
        )
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.badRequest(body)
            })
        )
        let service = DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())

        let error = await #expect(throws: WalletError.self) {
            _ = try await service.removeRecoveryMethod(
                .phone("+14155552671"),
                chainType: .solana,
                approver: .email("alice@example.com")
            )
        }

        #expect(error?.code == "LAST_RECOVERY_SIGNER")
        #expect(error?.message == "Cannot remove the last recovery signer")
    }
}
