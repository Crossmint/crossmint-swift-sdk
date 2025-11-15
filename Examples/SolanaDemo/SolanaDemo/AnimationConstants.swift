import SwiftUI

enum AnimationConstants {
    static let duration: Double = 0.3
    static let shortDuration: Double = 0.2

    static func easeIn(duration: Double = AnimationConstants.duration) -> Animation {
        return .easeIn(duration: duration)
    }

    static func easeOut(duration: Double = AnimationConstants.duration) -> Animation {
        return .easeOut(duration: duration)
    }

    static func easeInOut(duration: Double = AnimationConstants.duration) -> Animation {
        return .easeInOut(duration: duration)
    }
}
