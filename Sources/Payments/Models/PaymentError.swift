public enum PaymentError: Error {
    case quantityMustBeGreaterThanZero
    case invalidExecutionMode(expected: String, got: String)
    case decodingError(Error)

    var localizedDescription: String {
        switch self {
        case .quantityMustBeGreaterThanZero:
            return "Quantity must be greater than 0"
        case .invalidExecutionMode(let expected, let got):
            return "Invalid execution mode: expected '\(expected)' but got '\(got)'"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        }
    }
}
