import Foundation
import Http

public struct CheckoutComRequestBuilder: Sendable {
    public enum Error: Swift.Error {
        case invalidURL
    }

    public init() {}

    public func getRequest(
        forEndpoint endpoint: Http.Endpoint, onProductionEnvironment environment: Bool
    ) throws(Error) -> URLRequest {
        guard let url = try? getApiBaseURL(onProductionEnvironment: environment),
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            throw .invalidURL
        }
        components.path += endpoint.path
        components.queryItems = endpoint.queryItems

        guard let componentsUrl = components.url else {
            throw .invalidURL
        }
        var request = URLRequest(url: componentsUrl)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        let allHeaders: [String: String] = getBaseHeaders().merging(endpoint.headers) { _, new in
            new
        }
        allHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        return request
    }

    public func getApiBaseURL(onProductionEnvironment productionEnvironment: Bool) throws(Error) -> URL {
        if productionEnvironment {
            guard let url = URL(string: "https://api.checkout.com") else {
                throw .invalidURL
            }
            return url
        }

        guard let url = URL(string: "https://api.sandbox.checkout.com") else {
            throw .invalidURL
        }
        return url
    }

    private func getBaseHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json"
        ]
    }

}
