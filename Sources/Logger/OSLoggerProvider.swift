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

    nonisolated func debug(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.debug, log: osLogger, "%{public}@", formatMessage(message, attributes: attributes))
    }

    nonisolated func error(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.error, log: osLogger, "%{public}@", formatMessage(message, attributes: attributes))
    }

    nonisolated func info(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.info, log: osLogger, "%{public}@", formatMessage(message, attributes: attributes))
    }

    nonisolated func warn(_ message: String, attributes: [String: any Encodable]?) {
        os_log(.default, log: osLogger, "%{public}@", formatMessage(message, attributes: attributes))
    }

    private func formatMessage(_ message: String, attributes: [String: any Encodable]?) -> String {
        guard let attributes = attributes, !attributes.isEmpty else {
            return message
        }

        let attributeStrings = attributes.map { key, value in
            "\(key)=\(value)"
        }.sorted().joined(separator: " ")

        return "\(message) \(attributeStrings)"
    }
}
