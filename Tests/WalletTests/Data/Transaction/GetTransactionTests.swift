import CrossmintService
import Foundation
import Testing
import TestsUtils

@testable import Http
@testable import Wallet

@Suite("Get Transaction", .tags(.unit))
struct GetTransactionTests {
    private final class RequestCapture: @unchecked Sendable {
        var request: URLRequest?
    }

    private func makeService(httpClient: HTTPClient) throws -> DefaultTransactionService {
        let crossmintService = DefaultCrossmintService(
            apiKey: try ApiKey(key: "ck_staging_test123"),
            appIdentifier: "com.crossmint.tests",
            httpClient: httpClient
        )
        return DefaultTransactionService(crossmintService: crossmintService, jsonCoder: DefaultJSONCoder())
    }

    private func makeService(returning body: Data, capture: RequestCapture? = nil) throws -> DefaultTransactionService {
        try makeService(
            httpClient: HTTPClient(fetch: { request throws(NetworkError) in
                capture?.request = request
                return (body, URLResponse())
            })
        )
    }

    private func fixtureData(_ fileName: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: fileName, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    @Test func decodesEVMTransaction() async throws {
        let service = try makeService(returning: try fixtureData("GetTransactionResponse"))

        let transaction = try await service.fetchTransaction(
            .init(transactionId: "42bbb192-1707-43ba-bd21-6e96d28bdcc9", chainType: .evm)
        )

        let model = try #require(transaction as? EVMTransactionApiModel)
        #expect(model.id == "42bbb192-1707-43ba-bd21-6e96d28bdcc9")
        #expect(model.status == .success)
    }

    @Test func decodesSolanaTransactionWithChainDrivenModel() async throws {
        let service = try makeService(returning: try fixtureData("CreateSolanaTransactionResponse"))

        let transaction = try await service.fetchTransaction(
            .init(transactionId: "f662d74d-8790-4dbe-8865-93916b39d3d6", chainType: .solana)
        )

        let model = try #require(transaction as? SolanaTransactionApiModel)
        #expect(model.id == "f662d74d-8790-4dbe-8865-93916b39d3d6")
        #expect(model.status == .awaitingApproval)
    }

    @Test func requestsMeWalletTransactionPathWithGetMethod() async throws {
        let capture = RequestCapture()
        let service = try makeService(returning: try fixtureData("GetTransactionResponse"), capture: capture)

        _ = try await service.fetchTransaction(.init(transactionId: "tx-123", chainType: .evm))

        let request = try #require(capture.request)
        let url = try #require(request.url)
        #expect(request.httpMethod == "GET")
        #expect(url.path.hasSuffix("/2025-06-09/wallets/me:evm/transactions/tx-123"))
        #expect(request.httpBody == nil)
    }

    @Test func mapsHttpErrorToTransactionError() async throws {
        let errorBody = Data(#"{"error": true, "message": "boom"}"#.utf8)
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.badRequest(errorBody)
            })
        )

        await #expect {
            _ = try await service.fetchTransaction(.init(transactionId: "tx-123", chainType: .evm))
        } throws: { error in
            guard case .transactionGeneric(let message) = error as? TransactionError else { return false }
            return message == "boom"
        }
    }

    @Test func failsWhenResponseDoesNotMatchChainModel() async throws {
        let service = try makeService(returning: Data(#"{"id": "tx-1"}"#.utf8))

        await #expect {
            _ = try await service.fetchTransaction(.init(transactionId: "tx-1", chainType: .evm))
        } throws: { error in
            guard case .transactionGeneric(let message) = error as? TransactionError else { return false }
            return message == "Failed to decode transaction response"
        }
    }

    @Suite("when mapping the API model to the domain")
    struct DomainMappingTests {
        @Test func mapsDecodedTransactionToDomain() async throws {
            let model: EVMTransactionApiModel = try GetFromFile.getModelFrom(
                fileName: "GetTransactionResponse",
                bundle: Bundle.module
            )

            let transaction = try #require(model.toDomain())

            #expect(transaction.id == "42bbb192-1707-43ba-bd21-6e96d28bdcc9")
            #expect(transaction.status == .success)
            #expect(transaction.onChain.txId == "0x9f52ec9b7e3a6a5c6a4d2f1f0f7f3f0a4a1b2c3d4e5f60718293a4b5c6d7e8f9")
            #expect(transaction.params.signer == "external-wallet:0x20112298f0fb356fb914fb00548b2c86083126cc")
        }
    }
}
