import Foundation

public protocol JSONCoder: Sendable {
    func encode<T>(
        _ instance: T
    ) throws(CrossmintServiceError) -> Data where T: Encodable

    func decode<T>(
        _ type: T.Type,
        from data: Data
    ) throws(CrossmintServiceError) -> T where T: Decodable
}

public extension JSONCoder {
    func encodeRequest<T: Encodable, E: ServiceError>(
        _ request: T,
        errorType: E.Type
    ) throws(E) -> Data {
        return try RequestEncodingUtility.encodeRequest(
            request,
            using: self,
            errorType: errorType
        )
    }
}
