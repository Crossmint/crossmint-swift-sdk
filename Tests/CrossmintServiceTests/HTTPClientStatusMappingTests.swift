import Foundation
import Testing
import TestsUtils
@testable import Http

@Suite("HTTPClient status mapping", .tags(.unit))
struct HTTPClientStatusMappingTests {
    private let body = Data("{}".utf8)

    private func response(_ status: Int) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://staging.crossmint.com/api/test"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    }

    @Test(arguments: [200, 201, 204, 299])
    func passesASuccessfulResponseThrough(status: Int) throws {
        let (data, _) = try HTTPClient.mapStatus(data: body, response: try response(status))
        #expect(data == body)
    }

    @Test(arguments: [
        (400, "Bad request"), (401, "Unauthorized"), (403, "Forbidden"), (404, "Not found"),
        (500, "Server error"), (503, "Server error"), (418, "Invalid status code (418)")
    ])
    func mapsAnErrorStatusToItsNetworkError(status: Int, expected: String) throws {
        let response = try response(status)
        #expect {
            try HTTPClient.mapStatus(data: body, response: response)
        } throws: { error in
            (error as? NetworkError)?.errorDescription?.hasPrefix(expected) == true
        }
    }

    @Test func rejectsAResponseThatIsNotHTTP() {
        #expect {
            try HTTPClient.mapStatus(data: body, response: URLResponse())
        } throws: { error in
            guard case .invalidStatusCode(let code, _) = error as? NetworkError else { return false }
            return code == -1
        }
    }
}
