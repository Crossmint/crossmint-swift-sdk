import CrossmintService
import Foundation
import Http

public struct CheckoutComService: CrossmintService {
    private let requestBuilder: CheckoutComRequestBuilder
    private let httpClient: HTTPClient
    private let jsonCoder: JSONCoder
    private let productionEnvironment: Bool

    public var isProductionEnvironment: Bool {
        productionEnvironment
    }

    public init(
        productionEnvironment: Bool,
        httpClient: HTTPClient = .live,
        requestBuilder: CheckoutComRequestBuilder = CheckoutComRequestBuilder(),
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        self.productionEnvironment = productionEnvironment
        self.requestBuilder = requestBuilder
        self.httpClient = httpClient
        self.jsonCoder = jsonCoder
    }

    public func executeRequest<T, E>(
        _ endpoint: Http.Endpoint,
        errorType: E.Type,
        _ transform: (Http.NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: ServiceError {
        do {
            let (data, _) = try await httpClient.fetch(try getRequest(endpoint))
            return try jsonCoder.decode(T.self, from: data)
        } catch let networkError as NetworkError {
            if let mappedError = transform(networkError) {
                throw mappedError
            }

            throw E.fromNetworkError(networkError)
        } catch let serviceError as CrossmintServiceError {
            throw E.fromServiceError(serviceError)
        } catch {
            // This type of error should never happen.
            throw E.fromServiceError(.unknown)
        }
    }

    @available(*, deprecated, message: "Use the new version of execute")
    public func executeRequest<T, E>(
        _ endpoint: Endpoint,
        _ transform: (NetworkError) -> E? = { _ in nil }
    ) async throws(E) -> T where T: Decodable, E: ServiceError {
        do {
            let (data, _) = try await httpClient.fetch(try getRequest(endpoint))
            return try jsonCoder.decode(T.self, from: data)
        } catch let networkError as NetworkError {
            if let mappedError = transform(networkError) {
                throw mappedError
            }

            throw E.fromNetworkError(networkError)
        } catch let serviceError as CrossmintServiceError {
            throw E.fromServiceError(serviceError)
        } catch {
            // This type of error should never happen.
            throw E.fromServiceError(.unknown)
        }
    }

    public func executeRequest<E>(
        _ endpoint: Http.Endpoint,
        errorType: E.Type,
        _ transform: (Http.NetworkError) -> E?
    ) async throws(E) where E: ServiceError {
        do {
            _ = try await httpClient.fetch(try getRequest(endpoint))

        } catch {
            if let mappedError = transform(error) {
                throw mappedError
            }

            throw E.fromNetworkError(error)
        }
    }

    public func executeRequestForRawData<E>(
        _ endpoint: Http.Endpoint,
        errorType: E.Type,
        _ transform: (Http.NetworkError) -> E? = { _ in nil }
    ) async throws(E) -> Data where E: ServiceError {
        let request: URLRequest
        do {
            request = try getRequest(endpoint)
        } catch let networkError {
            if let mappedError = transform(networkError) {
                throw mappedError
            }
            throw E.fromNetworkError(networkError)
        }

        do {
            let (data, _) = try await httpClient.fetch(request)
            return data
        } catch let networkError {
            if let mappedError = transform(networkError) {
                throw mappedError
            }
            throw E.fromNetworkError(networkError)
        }
    }

    public func getApiBaseURL() throws(CrossmintServiceError) -> URL {
        do {
            return try requestBuilder.getApiBaseURL(onProductionEnvironment: isProductionEnvironment)
        } catch {
            throw .invalidURL
        }
    }

    private func getRequest(_ endpoint: Endpoint) throws (NetworkError) -> URLRequest {
        do {
            return try requestBuilder.getRequest(
                forEndpoint: endpoint,
                onProductionEnvironment: isProductionEnvironment
            )
        } catch {
            throw .unknown(error)
        }
    }
}
