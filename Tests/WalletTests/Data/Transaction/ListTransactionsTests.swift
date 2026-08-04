import CrossmintService
import Foundation
import Testing

@testable import Http
@testable import Wallet

@Suite("List Transactions", .tags(.unit))
struct ListTransactionsTests {
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

    @Test func decodesEVMTransactionList() async throws {
        let service = try makeService(returning: try fixtureData("ListTransactionsResponse"))

        let transactions = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))

        #expect(transactions.count == 2)
        let first = try #require(transactions.first)
        #expect(first.id == "42bbb192-1707-43ba-bd21-6e96d28bdcc9")
        #expect(first.status == .success)
        #expect(first.onChain.txId == "0x9f52ec9b7e3a6a5c6a4d2f1f0f7f3f0a4a1b2c3d4e5f60718293a4b5c6d7e8f9")
        #expect(first.params.signer == "external-wallet:0x20112298f0fb356fb914fb00548b2c86083126cc")
        #expect(transactions.last?.status == .pending)
    }

    @Test func decodesSolanaTransactionListWithChainDrivenModel() async throws {
        let service = try makeService(returning: try fixtureData("ListSolanaTransactionsResponse"))

        let transactions = try await service.listTransactions(.init(chainType: .solana, page: 1, perPage: 20))

        #expect(transactions.count == 1)
        let first = try #require(transactions.first)
        #expect(first.id == "f662d74d-8790-4dbe-8865-93916b39d3d6")
        #expect(first.status == .awaitingApproval)
    }

    @Test func returnsEmptyListWhenWalletHasNoTransactions() async throws {
        let service = try makeService(returning: Data(#"{"transactions": []}"#.utf8))

        let transactions = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))

        #expect(transactions.isEmpty)
    }

    @Test func requestsMeWalletTransactionsPathWithGetMethod() async throws {
        let capture = RequestCapture()
        let service = try makeService(returning: Data(#"{"transactions": []}"#.utf8), capture: capture)

        _ = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))

        let request = try #require(capture.request)
        let url = try #require(request.url)
        #expect(request.httpMethod == "GET")
        #expect(url.path.hasSuffix("/2025-06-09/wallets/me:evm/transactions"))
        #expect(request.httpBody == nil)
    }

    @Test func encodesPageAndPerPageAsQueryItems() async throws {
        let capture = RequestCapture()
        let service = try makeService(returning: Data(#"{"transactions": []}"#.utf8), capture: capture)

        _ = try await service.listTransactions(.init(chainType: .evm, page: 2, perPage: 15))

        let request = try #require(capture.request)
        let url = try #require(request.url)
        let queryItems = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(queryItems.contains(URLQueryItem(name: "page", value: "2")))
        #expect(queryItems.contains(URLQueryItem(name: "perPage", value: "15")))
    }

    @Test func mapsHttpErrorToTransactionError() async throws {
        let errorBody = Data(#"{"error": true, "message": "boom"}"#.utf8)
        let service = try makeService(
            httpClient: HTTPClient(fetch: { _ throws(NetworkError) in
                throw NetworkError.badRequest(errorBody)
            })
        )

        await #expect {
            _ = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))
        } throws: { error in
            guard case .transactionGeneric(let message) = error as? TransactionError else { return false }
            return message == "boom"
        }
    }

    @Test func dropsRowsThatDoNotMatchChainModel() async throws {
        let service = try makeService(returning: Data(#"{"transactions": [{"id": "tx-1"}]}"#.utf8))

        let transactions = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))

        #expect(transactions.isEmpty)
    }

    @Test func keepsValidRowsWhenAnotherRowFailsToDecode() async throws {
        let service = try makeService(returning: try fixtureData("ListTransactionsResponseWithBadRow"))

        let transactions = try await service.listTransactions(.init(chainType: .evm, page: 1, perPage: 20))

        #expect(transactions.count == 1)
        #expect(transactions.first?.id == "42bbb192-1707-43ba-bd21-6e96d28bdcc9")
    }
}
