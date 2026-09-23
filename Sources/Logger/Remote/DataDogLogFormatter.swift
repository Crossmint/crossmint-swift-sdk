//
//  DataDogLogFormatter.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 15/09/26.
//

import Foundation
import Utils

struct DataDogLogFormatter: Sendable {
    let loggerName: String
    let environment: String
    let sessionId: String
    let hostname: String?

    func payload(for entry: LogEntry, deviceInfo: DeviceInfoCache, threadName: String) -> [String: Any] {
        let reserved = reservedAttributes(for: entry, deviceInfo: deviceInfo, threadName: threadName)
        return entry.context.mapValues { $0 as Any }.merging(reserved) { _, reserved in reserved }
    }

    private func reservedAttributes(
        for entry: LogEntry,
        deviceInfo: DeviceInfoCache,
        threadName: String
    ) -> [String: Any] {
        let attributes: [String: Any?] = [
            "message": entry.message,
            "status": Self.status(for: entry.level),
            "service": "crossmint-ios-sdk",
            "ddsource": "ios",
            "ddtags": ddtags(for: deviceInfo),
            "hostname": hostname,
            "timestamp": entry.timestamp,
            "dd-session_id": sessionId,
            "platform": "ios",
            "version": deviceInfo.appVersion,
            "build_version": deviceInfo.appBuild,
            "os": Self.nonEmptyObject([
                "name": deviceInfo.osName,
                "version": deviceInfo.osVersion,
                "build": deviceInfo.osBuild
            ]),
            "device": Self.nonEmptyObject([
                "name": deviceInfo.deviceName,
                "model": deviceInfo.model,
                "brand": deviceInfo.brand,
                "architecture": deviceInfo.architecture
            ]),
            "network": Self.nonEmptyObject([
                "type": deviceInfo.networkConnectionType,
                "cellular_technology": deviceInfo.cellularTechnology
            ]).map { ["client": $0] },
            "logger": Self.nonEmptyObject([
                "name": loggerName,
                "version": SDKVersion.version,
                "thread_name": threadName,
                "app_id": hostname
            ])
        ]
        return attributes.compactMapValues { $0 }
    }

    private func ddtags(for deviceInfo: DeviceInfoCache) -> String {
        var tags = ["env:\(environment)", "sdk_version:\(SDKVersion.version)"]
        if let appVersion = deviceInfo.appVersion {
            tags.append("version:\(appVersion)")
        }
        return tags.joined(separator: ",")
    }

    private static func nonEmptyObject(_ values: [String: String?]) -> [String: String]? {
        let present = values.compactMapValues { $0 }
        return present.isEmpty ? nil : present
    }

    private static func status(for level: LogLevel) -> String {
        switch level {
        case .debug, .info: "info"
        case .warning: "warn"
        case .error: "error"
        case .silent: "none"
        }
    }
}
