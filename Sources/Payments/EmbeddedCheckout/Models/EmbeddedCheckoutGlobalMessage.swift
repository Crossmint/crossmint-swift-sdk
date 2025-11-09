import Foundation

public enum EmbeddedCheckoutGlobalMessageDisplayLocation {
    case top
    case bottom
}

public enum EmbeddedCheckoutMessageType {
    case error
    case devError
    case warning
}

public struct EmbeddedCheckoutGlobalMessage {
    public var message: String
    public var displayLocation: EmbeddedCheckoutGlobalMessageDisplayLocation
    public var type: EmbeddedCheckoutMessageType
    public var timeout: TimeInterval?
    public var fatal: Bool

    public init(
        message: String, displayLocation: EmbeddedCheckoutGlobalMessageDisplayLocation,
        type: EmbeddedCheckoutMessageType, timeout: TimeInterval? = nil, fatal: Bool
    ) {
        self.message = message
        self.displayLocation = displayLocation
        self.type = type
        self.timeout = timeout
        self.fatal = fatal
    }
}
