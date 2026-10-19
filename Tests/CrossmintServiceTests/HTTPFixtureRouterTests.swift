import Foundation
import Testing
import TestsUtils
@testable import Http

@Suite("HTTPFixtureRouter", .tags(.unit))
struct HTTPFixtureRouterTests {
    private let router = HTTPFixtureRouter()

    private func request(_ method: String, _ path: String) throws -> URLRequest {
        var request = URLRequest(url: try #require(URL(string: "https://staging.crossmint.com/api\(path)")))
        request.httpMethod = method
        return request
    }

    @Test func namesAnUnstubbedRequest() async throws {
        let request = try request("GET", "/2025-06-09/wallets/me:evm")
        await #expect {
            try await router.client.fetch(request)
        } throws: { error in
            guard case .unknown(let cause) = error as? NetworkError else { return false }
            return cause.localizedDescription
                .contains("GET https://staging.crossmint.com/api/2025-06-09/wallets/me:evm")
        }
    }

    @Test func mapsAStubbedStatusLikeTheLiveClient() async throws {
        router.respond(to: "POST", path: "/wallets", status: 400, json: #"{"message": "nope"}"#)
        let request = try request("POST", "/2025-06-09/wallets")

        await #expect {
            try await router.client.fetch(request)
        } throws: { error in
            (error as? NetworkError)?.serviceErrorMessage == "nope"
        }
    }

    @Test func matchesOnMethodAndPathSuffixAndRecordsEveryRequest() async throws {
        router.respond(to: "GET", path: "/wallets/me:evm", json: #"{"address": "0x1"}"#)

        let (data, _) = try await router.client.fetch(try request("GET", "/2025-06-09/wallets/me:evm"))
        let unstubbed = try request("DELETE", "/2025-06-09/wallets/me:evm")
        await #expect(throws: NetworkError.self) {
            try await router.client.fetch(unstubbed)
        }

        #expect(String(bytes: data, encoding: .utf8) == #"{"address": "0x1"}"#)
        #expect(router.requests.map { $0.httpMethod } == ["GET", "DELETE"])
    }
}
