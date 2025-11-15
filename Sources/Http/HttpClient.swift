import Foundation
import Logger

public struct HTTPClient: Sendable {
    public let fetch: @Sendable (URLRequest) async throws(NetworkError) -> (Data, URLResponse)
}

public extension HTTPClient {
    static var live: HTTPClient {
        HTTPClient(
            fetch: { request throws(NetworkError) in
                let (data, response): (Data, URLResponse)
                do {
                    (data, response) = try await URLSession.shared.data(for: request)
                    URLSession.log(data: data, response: response)
                } catch {
                    throw NetworkError.unknown(error)
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidStatusCode(-1, data)
                }

                switch httpResponse.statusCode {
                case 200...299:
                    return (data, response)
                case 400:
                    throw NetworkError.badRequest(data)
                case 401:
                    throw NetworkError.unauthorized(data)
                case 403:
                    throw NetworkError.forbidden(data)
                case 404:
                    throw NetworkError.notFound(data)
                case 500...599:
                    throw NetworkError.serverError(data)
                default:
                    throw NetworkError.invalidStatusCode(httpResponse.statusCode, data)
                }
            }
        )
    }
}
