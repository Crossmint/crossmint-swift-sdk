import Foundation

public func isRunningInPlayground() -> Bool {
    let isPlayground = Bundle.main.bundleIdentifier?.contains("com.apple.dt.playground") ?? false
    let isPlaygroundProcess = ProcessInfo.processInfo.processName == "playground"

    return isPlayground || isPlaygroundProcess
}

public func getStringEnvironment(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
}

public func getBoolEnvironment(_ key: String) -> Bool {
    getStringEnvironment(key)?.lowercased() == "true"
}
