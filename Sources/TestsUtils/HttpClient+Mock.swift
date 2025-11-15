import Foundation
@testable import Http

public extension HTTPClient {
    static func mock(
        returning mockData: Data = Data(),
        response: URLResponse = URLResponse()
    ) -> HTTPClient {
        HTTPClient(
            fetch: { _ in (mockData, response) }
        )
    }
}
