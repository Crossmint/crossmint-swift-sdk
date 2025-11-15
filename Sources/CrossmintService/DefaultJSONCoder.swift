import Foundation

public struct DefaultJSONCoder: JSONCoder {
    private let decoder: JSONDecoder = {
        var jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            // Try with fractional seconds first
            let formatterWithFractionalSeconds = ISO8601DateFormatter()
            formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            if let date = formatterWithFractionalSeconds.date(from: string) {
                return date
            }

            // Try without fractional seconds
            let formatterWithoutFractionalSeconds = ISO8601DateFormatter()
            formatterWithoutFractionalSeconds.formatOptions = [.withInternetDateTime]

            if let date = formatterWithoutFractionalSeconds.date(from: string) {
                return date
            }

            // If both fail, throw an error
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
        return jsonDecoder
    }()

    private let encoder: JSONEncoder = {
        var jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .custom { date, encoder in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let string = formatter.string(from: date)

            var container = encoder.singleValueContainer()
            try container.encode(string)
        }
        return jsonEncoder
    }()

    public init() {}

    public func encode<T>(
        _ instance: T
    ) throws(CrossmintServiceError) -> Data where T: Encodable {
        do {
            return try encoder.encode(instance)
        } catch {
            throw .invalidData("\(error.localizedDescription)(\(error)")
        }
    }

    public func decode<T>(
        _ type: T.Type,
        from data: Data
    ) throws(CrossmintServiceError) -> T where T: Decodable {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw .invalidData("\(error.localizedDescription)(\(error)")
        }
    }

}
