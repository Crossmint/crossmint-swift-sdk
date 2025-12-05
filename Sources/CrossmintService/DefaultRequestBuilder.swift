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
        let queryParams = endpoint.queryItems.urlSearchQuery
        guard let componentsUrl = URL(string: "\(baseUrl)/\(endpoint.path)\(queryParams)") else {
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

private extension Array where Element == URLQueryItem {
    // Join items as name=value pairs separated by '&'
    // For nil values, URLSearchParams serializes as name=
    var urlSearchQuery: String {
        guard !isEmpty else {
            return ""
        }
        return "?" + map { item in
            let name = item.name.formURLEncoded
            let value = item.value?.formURLEncoded ?? ""
            return "\(name)=\(value)"
        }
        .joined(separator: "&")
    }
}

private extension String {
    // Encode a single name or value using application/x-www-form-urlencoded rules:
    // - Alphanumerics and -._~ are left as-is
    // - Space becomes '+'
    // - '+' (and everything else outside the unreserved set) becomes percent-encoded
    var formURLEncoded: String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        // Convert encoded spaces (%20) to '+', matching URLSearchParams
        return encoded.replacingOccurrences(of: "%20", with: "+")
    }
}
