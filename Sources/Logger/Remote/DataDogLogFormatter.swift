//
//  DataDogLogFormatter.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 15/09/26.
//

import Foundation
import Utils

struct DataDogLogFormatter: Sendable {
    static let serviceName = "crossmint-ios-sdk"
    static let sourceName = "ios"
    static let platform = "ios"
    static let deviceBrand = "Apple"

    let loggerName: String
    let environment: String
    let sessionId: String
    let hostname: String

    func payload(for entry: LogEntry, deviceInfo: DeviceInfoCache, threadName: String) -> [String: Any] {
        var log: [String: Any] = entry.context.mapValues { $0 as Any }
        log.merge(reservedAttributes(for: entry, deviceInfo: deviceInfo)) { _, reserved in reserved }
        log.merge(structuredAttributes(for: deviceInfo, threadName: threadName)) { _, reserved in reserved }
        return log
    }

    private func reservedAttributes(for entry: LogEntry, deviceInfo: DeviceInfoCache) -> [String: Any] {
        [
            "message": entry.message,
            "status": Self.status(for: entry.level),
            "service": Self.serviceName,
            "ddsource": Self.sourceName,
            "ddtags": tags(appVersion: deviceInfo.appVersion),
            "hostname": hostname,
            "timestamp": entry.timestamp,
            "dd-session_id": sessionId,
            "platform": Self.platform,
            "version": deviceInfo.appVersion,
            "build_version": deviceInfo.appBuild
        ]
    }

    private func structuredAttributes(for deviceInfo: DeviceInfoCache, threadName: String) -> [String: Any] {
        [
            "os": [
                "name": deviceInfo.osName,
                "version": deviceInfo.osVersion,
                "build": deviceInfo.osBuild
            ],
            "device": [
                "name": deviceInfo.deviceName,
                "model": deviceInfo.model,
                "brand": Self.deviceBrand,
                "architecture": deviceInfo.architecture
            ],
            "network": network(for: deviceInfo),
            "logger": [
                "name": loggerName,
                "version": SDKVersion.version,
                "thread_name": threadName,
                "app_id": hostname
            ]
        ]
    }

    private func tags(appVersion: String) -> String {
        [
            "env:\(environment)",
            "sdk_version:\(SDKVersion.version)",
            "version:\(appVersion)"
        ].joined(separator: ",")
    }

    private func network(for deviceInfo: DeviceInfoCache) -> [String: Any] {
        var client: [String: Any] = ["type": deviceInfo.networkConnectionType]
        if let cellularTechnology = deviceInfo.cellularTechnology {
            client["cellular_technology"] = cellularTechnology
        }
        return ["client": client]
    }

    private static func status(for level: LogLevel) -> String {
        switch level {
        case .debug, .info:
            return "info"
        case .warning:
            return "warn"
        case .error:
            return "error"
        case .silent:
            return "none"
        }
    }
}
