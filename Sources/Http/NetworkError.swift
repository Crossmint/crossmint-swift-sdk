import Foundation

public enum NetworkError: LocalizedError {
    case unknown(Error)
    case badRequest(Data?)
    case unauthorized(Data?)
    case forbidden(Data?)
    case notFound(Data?)
    case timeout(Data?)
    case serverError(Data?)
    case invalidStatusCode(Int, Data?)

    public var errorDescription: String? {
        switch self {
        case .badRequest(let data):
            return "Bad request (400): \(parseErrorData(data))"
        case .unauthorized(let data):
            return "Unauthorized (401): \(parseErrorData(data))"
        case .forbidden(let data):
            return "Forbidden (403): \(parseErrorData(data))"
        case .notFound(let data):
            return "Not found (404): \(parseErrorData(data))"
        case .timeout(let data):
            return "Timeout (504): \(parseErrorData(data))"
        case .serverError(let data):
            return "Server error (500): \(parseErrorData(data))"
        case .invalidStatusCode(let code, let data):
            return "Invalid status code (\(code)): \(parseErrorData(data))"
        case let .unknown(error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }

    public var serviceErrorMessage: String? {
        guard let errorData = errorData else { return nil }
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: errorData, options: []) as? [String: Any],
                  let message = jsonObject["message"] as? String else {
                return nil
            }
            return message
        } catch {
            return nil
        }
    }

    private var errorData: Data? {
        switch self {
        case .badRequest(let data),
                .unauthorized(let data),
                .forbidden(let data),
                .notFound(let data),
                .timeout(let data),
                .serverError(let data),
                .invalidStatusCode(_, let data):
            return data
        case .unknown:
            return nil
        }
    }

    private func parseErrorData(_ data: Data?) -> String {
        guard let data = data else { return "No error details" }

        if let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }

        return String(data: data, encoding: .utf8) ?? "Unable to parse error data"
    }
}
