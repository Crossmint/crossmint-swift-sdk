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
    private let capturedRequest = SendableBox<URLRequest?>(nil)

    private func makeService(responding response: Result<String, NetworkError>) throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: HTTPClient(fetch: { [capturedRequest] request throws(NetworkError) in
                capturedRequest.value = request
                let fixture = try response.get()
                let url = Bundle.module.url(forResource: fixture, withExtension: "json")
                return (url.flatMap { try? Data(contentsOf: $0) } ?? Data(), URLResponse())
            })
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    @Test func postsTheRecoveryMethodAndTheApprover() async throws {
        let service = try makeService(responding: .success("AddRecoveryMethodResponse"))

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

    @Test func deletesTheEncodedLocatorAndMapsTheLastRecoverySignerCode() async throws {
        let body = #"{"message": "Cannot remove the last recovery signer", "code": "LAST_RECOVERY_SIGNER"}"#
        let service = try makeService(responding: .failure(.badRequest(Data(body.utf8))))

        let error = await #expect(throws: WalletError.self) {
            _ = try await service.removeRecoveryMethod(
                .phone("+14155552671"),
                chainType: .solana,
                approver: .email("alice@example.com")
            )
        }

        let url = try #require(capturedRequest.value?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(capturedRequest.value?.httpMethod == "DELETE")
        #expect(components.percentEncodedPath.hasSuffix(
            "/2025-06-09/wallets/me:solana/recovery-methods/phone:%2B14155552671"
        ))
        #expect(components.queryItems == [URLQueryItem(name: "approver", value: "email:alice@example.com")])
        #expect(error?.code == "LAST_RECOVERY_SIGNER")
        #expect(error?.message == "Cannot remove the last recovery signer")
    }
}
