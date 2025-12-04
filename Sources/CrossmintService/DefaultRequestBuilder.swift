import Foundation
import Http
import Utils

public struct DefaultRequestBuilder: RequestBuilder {
    private let whitelistedDomainHack: String?
    public init() {
        whitelistedDomainHack = getStringEnvironment("CROSSMINT_WHITELISTED_DOMAIN")
    }

    public func getRequest(
        forEndpoint endpoint: Endpoint,
        withKey key: ApiKey,
        andAppIdentifier appIdentifier: String
    ) throws(RequestBuilderError) -> URLRequest {
        let baseUrl = try getApiBaseURL(forApiKey: key)
        guard var components = URLComponents(url: baseUrl, resolvingAgainstBaseURL: true) else {
            throw .invalidURL
        }
        components.path += endpoint.path
        components.queryItems = endpoint.queryItems
       
        components.percentEncodedQuery = components.percentEncodedQuery?
          .replacingOccurrences(of: "+", with: "%2B")

        guard let componentsUrl = components.url else {
            throw .invalidURL
        }
        var request = URLRequest(url: componentsUrl)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        let allHeaders: [String: String] = getBaseHeaders(
            forApiKey: key,
            andAppIdentifier: appIdentifier
        ).merging(endpoint.headers) { _, new in new }
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return request
    }

    public func getApiBaseURL(forApiKey key: ApiKey) throws(RequestBuilderError) -> URL {
        guard let url = URL(string: "https://\(key.apiEnvironmentPathComponent)crossmint.com/api") else {
            throw .invalidURL
        }
        return url
    }

    private func getBaseHeaders(
        forApiKey key: ApiKey,
        andAppIdentifier appIdentifier: String
    ) -> [String: String] {
        [
            "Content-Type": "application/json",
            "X-API-KEY": key.key,
            "X-APP-IDENTIFIER": appIdentifier
        ].merging((whitelistedDomainHack.map { ["Origin": $0] } ?? [:])) { _, new in new }
    }
}
