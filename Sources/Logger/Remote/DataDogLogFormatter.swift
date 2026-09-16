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
    let hostname: String

    func payload(for entry: LogEntry, deviceInfo: DeviceInfoCache, threadName: String) -> [String: Any] {
        let reserved: [String: Any] = [
            "message": entry.message,
            "status": Self.status(for: entry.level),
            "service": "crossmint-ios-sdk",
            "ddsource": "ios",
            "ddtags": "env:\(environment),sdk_version:\(SDKVersion.version),version:\(deviceInfo.appVersion)",
            "hostname": hostname,
            "timestamp": entry.timestamp,
            "dd-session_id": sessionId,
            "platform": "ios",
            "version": deviceInfo.appVersion,
            "build_version": deviceInfo.appBuild,
            "os": [
                "name": deviceInfo.osName,
                "version": deviceInfo.osVersion,
                "build": deviceInfo.osBuild
            ],
            "device": [
                "name": deviceInfo.deviceName,
                "model": deviceInfo.model,
                "brand": "Apple",
                "architecture": deviceInfo.architecture
            ],
            "network": [
                "client": [
                    "type": deviceInfo.networkConnectionType,
                    "cellular_technology": deviceInfo.cellularTechnology
                ].compactMapValues { $0 }
            ],
            "logger": [
                "name": loggerName,
                "version": SDKVersion.version,
                "thread_name": threadName,
                "app_id": hostname
            ]
        ]
        return entry.context.mapValues { $0 as Any }.merging(reserved) { _, reserved in reserved }
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
