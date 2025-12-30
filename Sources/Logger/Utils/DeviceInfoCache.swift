//
//  DeviceInfoCache.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 29/12/24.
//

import Foundation
#if canImport(UIKit)
@preconcurrency import UIKit
#endif

struct DeviceInfoCache: @unchecked Sendable {
    let model: String
    let deviceName: String
    let osName: String
    let osVersion: String
    let osBuild: String
    let architecture: String
    let appVersion: String
    let appBuild: String

    #if canImport(UIKit)
    private nonisolated(unsafe) static func getDeviceModel() -> String {
        if Thread.isMainThread {
            return UIDevice.current.model
        } else {
            return DispatchQueue.main.sync { UIDevice.current.model }
        }
    }

    private nonisolated(unsafe) static func getDeviceName() -> String {
        if Thread.isMainThread {
            return UIDevice.current.name
        } else {
            return DispatchQueue.main.sync { UIDevice.current.name }
        }
    }

    private nonisolated(unsafe) static func getOSName() -> String {
        if Thread.isMainThread {
            return UIDevice.current.systemName
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemName }
        }
    }

    private nonisolated(unsafe) static func getOSVersion() -> String {
        if Thread.isMainThread {
            return UIDevice.current.systemVersion
        } else {
            return DispatchQueue.main.sync { UIDevice.current.systemVersion }
        }
    }

    private static func getOSBuild() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var build = [UInt8](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &build, &size, nil, 0)
        return String(decoding: build.prefix(while: { $0 != 0 }), as: UTF8.self)
    }

    private static func getArchitecture() -> String {
        #if arch(arm64e)
        return "arm64e"
        #elseif arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }

    static func capture() -> DeviceInfoCache {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        return DeviceInfoCache(
            model: getDeviceModel(),
            deviceName: getDeviceName(),
            osName: getOSName(),
            osVersion: getOSVersion(),
            osBuild: getOSBuild(),
            architecture: getArchitecture(),
            appVersion: appVersion,
            appBuild: appBuild
        )
    }
    #else

    static func capture() -> DeviceInfoCache {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"

        return DeviceInfoCache(
            model: "macOS",
            deviceName: ProcessInfo.processInfo.hostName,
            osName: "macOS",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            osBuild: "unknown",
            architecture: "unknown",
            appVersion: appVersion,
            appBuild: appBuild
        )
    }
    #endif
}
