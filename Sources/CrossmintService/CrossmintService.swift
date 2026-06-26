import Foundation
import Http

public enum CrossmintServiceError: CrossmintError {
    case unknown
    case invalidData(String)
    case invalidApiKey(String)
    case timeout
    case invalidURL

    public var code: String {
        switch self {
        case .unknown: "SERVICE_ERROR"
        case .invalidData: "INVALID_DATA"
        case .invalidApiKey: "INVALID_API_KEY"
        case .timeout: "TIMEOUT"
        case .invalidURL: "INVALID_URL"
        }
    }

    public var message: String {
        switch self {
        case .unknown:
            "Unknown error"
        case .invalidData(let detail):
            "Invalid data: \(detail)"
        case .invalidApiKey(let detail):
            "Invalid API key: \(detail)"
        case .invalidURL:
            "Invalid URL"
        case .timeout:
            "Timeout"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .invalidApiKey:
            "Verify your API key in the Crossmint developer console."
        case .timeout:
            "Check your network connection and retry the request."
        default:
            nil
        }
    }
}

public protocol CrossmintService: Sendable {
    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: CrossmintMappableError

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) where E: CrossmintMappableError

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> Data where E: CrossmintMappableError

    func getApiBaseURL() throws(CrossmintServiceError) -> URL

    var isProductionEnvironment: Bool { get }
}

public extension CrossmintService {
    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) -> T where T: Decodable, E: CrossmintMappableError {
        try await self.executeRequest(endpoint, errorType: errorType, { _ in nil })
    }

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) where E: CrossmintMappableError {
        let _: Void = try await self.executeRequest(endpoint, errorType: errorType, { _ in nil })
    }

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type
    ) async throws(E) -> Data where E: CrossmintMappableError {
        try await self.executeRequestForRawData(endpoint, errorType: errorType, { _ in nil })
    }
}

public protocol AuthenticatedService: Sendable {
    var authHeaders: [String: String] { get async }
}
