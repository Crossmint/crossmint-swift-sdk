import Foundation
import Http

public struct DefaultCrossmintService: CrossmintService {
    private let apiKey: ApiKey
    private let appIdentifier: String
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let jsonCoder: JSONCoder

    public var isProductionEnvironment: Bool {
        apiKey.environment == .production
    }

    public init(
        apiKey: ApiKey,
        appIdentifier: String,
        httpClient: HTTPClient = .live,
        requestBuilder: RequestBuilder = DefaultRequestBuilder(),
        jsonCoder: JSONCoder = DefaultJSONCoder()
    ) {
        self.apiKey = apiKey
        self.appIdentifier = appIdentifier
        self.httpClient = httpClient
        self.requestBuilder = requestBuilder
        self.jsonCoder = jsonCoder
    }

    public func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
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
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E? = { _ in nil }
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
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E? = { _ in nil }
    ) async throws(E) -> Data where E: ServiceError {
        do {
            let (data, _) = try await httpClient.fetch(try getRequest(endpoint))
            return data
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

    public func getApiBaseURL() throws(CrossmintServiceError) -> URL {
        do {
            return try requestBuilder.getApiBaseURL(forApiKey: apiKey)
        } catch {
            throw .invalidURL
        }
    }

    private func getRequest(_ endpoint: Endpoint) throws (NetworkError) -> URLRequest {
        do {
            return try requestBuilder.getRequest(
                forEndpoint: endpoint,
                withKey: apiKey,
                andAppIdentifier: appIdentifier
            )
        } catch {
            throw .unknown(error)
        }
    }
}
