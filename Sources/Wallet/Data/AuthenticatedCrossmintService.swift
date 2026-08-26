import CrossmintAuth
import CrossmintService
import Foundation
import Http

struct AuthenticatedCrossmintService: CrossmintService {
    let base: CrossmintService
    let authManager: AuthManager

    var isProductionEnvironment: Bool { base.isProductionEnvironment }

    func executeRequest<T, E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> T where T: Decodable, E: CrossmintMappableError {
        try await base.executeRequest(await withAuth(endpoint), errorType: errorType, transform)
    }

    func executeRequest<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) where E: CrossmintMappableError {
        try await base.executeRequest(await withAuth(endpoint), errorType: errorType, transform)
    }

    func executeRequestForRawData<E>(
        _ endpoint: Endpoint,
        errorType: E.Type,
        _ transform: (NetworkError) -> E?
    ) async throws(E) -> Data where E: CrossmintMappableError {
        try await base.executeRequestForRawData(await withAuth(endpoint), errorType: errorType, transform)
    }

    func getApiBaseURL() throws(CrossmintServiceError) -> URL {
        try base.getApiBaseURL()
    }

    private func withAuth(_ endpoint: Endpoint) async -> Endpoint {
        guard let jwt = await authManager.jwt else { return endpoint }
        var headers = endpoint.headers
        headers["Authorization"] = "Bearer \(jwt)"
        return Endpoint(
            path: endpoint.path,
            method: endpoint.method,
            headers: headers,
            queryItems: endpoint.queryItems,
            body: endpoint.body
        )
    }
}
