import Foundation
import Http

public protocol ServiceError: Swift.Error {
    static func fromServiceError(_ error: CrossmintServiceError) -> Self
    static func fromNetworkError(_ error: NetworkError) -> Self

    var errorMessage: String { get }
}

public enum CrossmintServiceError: Swift.Error {
    case unknown
    case invalidData(String)
    case invalidApiKey(String)
    case timeout
    case invalidURL

    public var errorMessage: String {
        switch self {
        case .unknown:
            "Unknown error"
        case .invalidData(let message):
            "Invalid data: \(message)"
        case .invalidApiKey(let message):
            "Invalid API key: \(message)"
        case .invalidURL:
            "Invalid URL"
        case .timeout:
            "Timeout"
        }
    }
}

public protocol CrossmintService: Sendable {
    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: ServiceError

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) where E: ServiceError

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> Data where E: ServiceError

    func getApiBaseURL() throws(CrossmintServiceError) -> URL

    var isProductionEnvironment: Bool { get }
}

public extension CrossmintService {
    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) -> T where T: Decodable, E: ServiceError {
        try await self.executeRequest(endpoint, errorType: errorType, { _ in nil })
    }

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) where E: ServiceError {
        let _: Void = try await self.executeRequest(endpoint, errorType: errorType, { _ in nil })
    }

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) -> Data where E: ServiceError {
        try await self.executeRequestForRawData(endpoint, errorType: errorType, { _ in nil })
    }
}

public protocol AuthenticatedService: Sendable {
    var authHeaders: [String: String] { get async }
}
