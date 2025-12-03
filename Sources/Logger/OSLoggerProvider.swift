//
//  OSLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import OSLog

public final class OSLoggerProvider: LoggerProvider {
    private let osLogger: OSLog
    private let subsystem: String

    public init(category: String) {
        self.subsystem = "CrossmintSDK"
        self.osLogger = OSLog(subsystem: subsystem, category: category)
    }

    func debug(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.debug, log: osLogger, "%{public}@", message)
    }

    func error(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.error, log: osLogger, "%{public}@", message)
    }

    func info(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.info, log: osLogger, "%{public}@", message)
    }

    func warn(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.default, log: osLogger, "%{public}@", message)
    }
}
