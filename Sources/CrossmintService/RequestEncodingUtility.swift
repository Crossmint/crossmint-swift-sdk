import Foundation

enum RequestEncodingUtility {
    static func encodeRequest<T: Encodable, E: ServiceError>(
        _ request: T,
        using jsonCoder: JSONCoder,
        errorType: E.Type
    ) throws(E) -> Data {
        do {
            return try jsonCoder.encode(request)
        } catch {
            throw E.fromServiceError(error)
        }
    }
}
