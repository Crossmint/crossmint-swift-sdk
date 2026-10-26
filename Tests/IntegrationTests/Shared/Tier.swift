import Foundation
import Testing

enum Tier {
    static let HEARTBEAT_VARIABLE = "HEARTBEAT"
    static let heartbeatRequested = ProcessInfo.processInfo.environment[HEARTBEAT_VARIABLE] == "1"

    static var integration: ConditionTrait { .disabled(if: heartbeatRequested, "heartbeat run") }
    static var heartbeat: ConditionTrait { .enabled(if: heartbeatRequested, "set TEST_RUNNER_HEARTBEAT=1") }
}
