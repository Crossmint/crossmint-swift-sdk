public struct PasskeyError: Error {
    var type: PasskeyErrorType

    var message: String?
}

public enum PasskeyErrorType: String, Sendable {

    case notSupported = "NotSupported"

    case requestFailed = "RequestFailed"

    case cancelled = "UserCancelled"

    case invalidChallenge = "InvalidChallenge"

    case invalidUser = "InvalidUser"

    case badConfiguration = "BadConfiguration"

    case timedOut = "TimedOut"

    case unknown = "UnknownError"
}
