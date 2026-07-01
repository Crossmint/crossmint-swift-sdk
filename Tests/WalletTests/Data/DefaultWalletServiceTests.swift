import CrossmintService
import Foundation
import Testing

@testable import Http
@testable import Wallet

@Suite("Signer Registration API Errors", .tags(.unit))
struct DefaultWalletServiceTests {
    private let entry = DelegatedSignerEntry(signer: "device:test-key")

    private func makeService(httpClient: HTTPClient) throws -> DefaultWalletService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: httpClient
        )
        return DefaultWalletService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func makeService(errorBody: Data) throws -> DefaultWalletService {
        try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.badRequest(errorBody)
            })
        )
    }

    @Test
    func decodesChainsRegistrationResponse() async throws {
        let body = Data(
            """
            {"chains": {"solana": {"id": "sig1", "status": "success"}}}
            """.utf8
        )
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in (body, URLResponse()) })
        )

        let response = try await service.addSigner(entry, chainType: .solana, chainName: "solana")

        #expect(response.chains?["solana"]?.id == "sig1")
    }

    @Test
    func decodesTransactionRegistrationResponse() async throws {
        let body = Data(#"{"transaction": {"id": "tx-123", "status": "awaiting-approval"}}"#.utf8)
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in (body, URLResponse()) })
        )

        let response = try await service.addSigner(entry, chainType: .solana, chainName: "solana")

        #expect(response.transaction?.id == "tx-123")
    }

    @Test
    func throwsTypedErrorForDeviceSignerNotSupportedCode() async throws {
        let body = Data(
            """
            {
                "error": true,
                "message": "Device signers are not supported for this provider",
                "code": "DEVICE_SIGNER_NOT_SUPPORTED"
            }
            """.utf8
        )
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana")
        } throws: { error in
            guard case .deviceSignerNotSupported(let message) = error as? WalletError else { return false }
            return message == "Device signers are not supported for this provider"
        }
    }

    @Test
    func usesFallbackMessageWhenErrorBodyOmitsMessage() async throws {
        let body = Data(#"{"error": true, "code": "DEVICE_SIGNER_NOT_SUPPORTED"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana")
        } throws: { error in
            guard case .deviceSignerNotSupported(let message) = error as? WalletError else { return false }
            return message == "Device signers are not supported for this wallet's provider."
        }
    }

    @Test
    func keepsGenericErrorForOtherCodes() async throws {
        let body = Data(#"{"error": true, "message": "boom", "code": "SOMETHING_ELSE"}"#.utf8)
        let service = try makeService(errorBody: body)

        await #expect {
            _ = try await service.addSigner(entry, chainType: .solana, chainName: "solana")
        } throws: { error in
            if case .deviceSignerNotSupported = error as? WalletError { return false }
            return true
        }
    }
}
