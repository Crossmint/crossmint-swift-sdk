import Foundation

public enum WebViewError: Error, Equatable {
    case webViewNotAvailable
    case timeout
    case encodingError
    case decodingError
    case navigationFailed(Error)
    case javascriptEvaluationError

    public static func == (lhs: WebViewError, rhs: WebViewError) -> Bool {
        switch (lhs, rhs) {
        case (.webViewNotAvailable, .webViewNotAvailable),
             (.timeout, .timeout),
             (.encodingError, .encodingError),
             (.decodingError, .decodingError),
             (.javascriptEvaluationError, .javascriptEvaluationError):
            return true
        case (.navigationFailed(let lhsError), .navigationFailed(let rhsError)):
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}
