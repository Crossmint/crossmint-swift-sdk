import Foundation
import Http

public enum RequestBuilderError: Error {
    case invalidURL
}

public protocol RequestBuilder: Sendable {
    func getRequest(
        forEndpoint endpoint: Endpoint,
        withKey key: ApiKey,
        andAppIdentifier appIdentifier: String
    ) throws(RequestBuilderError) -> URLRequest

    func getApiBaseURL(forApiKey key: ApiKey) throws(RequestBuilderError) -> URL
}
