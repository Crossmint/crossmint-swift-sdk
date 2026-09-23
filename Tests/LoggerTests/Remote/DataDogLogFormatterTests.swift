//
//  DataDogLogFormatterTests.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 15/09/26.
//

import Foundation
@testable import Logger
import Testing
import Utils

@Suite("DataDog log payload", .tags(.unit))
struct DataDogLogFormatterTests {
    static let LOGGER_NAME = "wallet"
    static let SESSION_ID = "0123456789abcdef"
    static let HOSTNAME = "com.example.app"
    static let THREAD_NAME = "main"
    static let STRUCTURED_OBJECTS: [(String, [String: String])] = [
        ("os", ["name": "iOS", "version": "26.0", "build": "23A340"]),
        ("device", ["name": "Tomas iPhone", "model": "iPhone", "brand": "Apple", "architecture": "arm64e"]),
        ("logger", [
            "name": LOGGER_NAME, "version": SDKVersion.version, "thread_name": THREAD_NAME, "app_id": HOSTNAME
        ])
    ]
    static let NETWORK_CLIENTS: [(String?, [String: String])] = [
        ("5G", ["type": "cellular", "cellular_technology": "5G"]),
        (nil, ["type": "wifi"])
    ]

    let formatter = DataDogLogFormatter(
        loggerName: LOGGER_NAME,
        environment: "production",
        sessionId: SESSION_ID,
        hostname: HOSTNAME
    )

    static func makeDeviceInfo(
        networkConnectionType: String? = "cellular",
        cellularTechnology: String? = "5G"
    ) -> DeviceInfoCache {
        DeviceInfoCache(
            model: "iPhone", deviceName: "Tomas iPhone", brand: "Apple", osName: "iOS", osVersion: "26.0",
            osBuild: "23A340", architecture: "arm64e", appVersion: "3.1.4", appBuild: "42",
            networkConnectionType: networkConnectionType, cellularTechnology: cellularTechnology
        )
    }

    static func makeEntry(level: LogLevel = .info, context: [String: Encodable] = [:]) -> LogEntry {
        LogEntry(level: level, message: "wallet created", timestamp: "2026-09-15T10:00:00Z", context: context)
    }

    func payload(
        level: LogLevel = .info,
        context: [String: Encodable] = [:],
        deviceInfo: DeviceInfoCache = makeDeviceInfo()
    ) -> [String: Any] {
        formatter.payload(
            for: Self.makeEntry(level: level, context: context),
            deviceInfo: deviceInfo,
            threadName: Self.THREAD_NAME
        )
    }

    @Test func sendsReservedAttributesAtTopLevel() {
        let payload = payload()

        #expect(payload["ddtags"] as? String == "env:production,sdk_version:\(SDKVersion.version),version:3.1.4")
        #expect(payload["ddsource"] as? String == "ios")
        #expect(payload["message"] as? String == "wallet created")
        #expect(payload["service"] as? String == "crossmint-ios-sdk")
        #expect(payload["hostname"] as? String == Self.HOSTNAME)
        #expect(payload["timestamp"] as? String == "2026-09-15T10:00:00Z")
        #expect(payload["dd-session_id"] as? String == Self.SESSION_ID)
        #expect(payload["platform"] as? String == "ios")
        #expect(payload["version"] as? String == "3.1.4")
        #expect(payload["build_version"] as? String == "42")
    }

    @Test(arguments: STRUCTURED_OBJECTS)
    func sendsStructuredObjectsAtTopLevel(key: String, expected: [String: String]) {
        #expect(payload()[key] as? [String: String] == expected)
    }

    @Test(arguments: NETWORK_CLIENTS)
    func sendsNetworkClientAtTopLevel(cellularTechnology: String?, expected: [String: String]) throws {
        let deviceInfo = Self.makeDeviceInfo(
            networkConnectionType: expected["type"],
            cellularTechnology: cellularTechnology
        )

        let network = try #require(payload(deviceInfo: deviceInfo)["network"] as? [String: Any])

        #expect(network["client"] as? [String: String] == expected)
    }

    @Test func mergesContextAtTopLevelWithoutOverridingReservedKeys() {
        let payload = payload(context: ["chain": "base-sepolia", "attempt": 2, "status": "pending", "service": "x"])

        #expect(payload["chain"] as? String == "base-sepolia")
        #expect(payload["attempt"] as? Int == 2)
        #expect(payload["status"] as? String == "info")
        #expect(payload["service"] as? String == "crossmint-ios-sdk")
    }

    @Test(arguments: [
        (LogLevel.debug, "info"),
        (LogLevel.info, "info"),
        (LogLevel.warning, "warn"),
        (LogLevel.error, "error"),
        (LogLevel.silent, "none")
    ])
    func mapsLevelToDatadogStatus(level: LogLevel, status: String) {
        #expect(payload(level: level)["status"] as? String == status)
    }

    @Test func serializesFlatPayloadToJson() throws {
        let data = try JSONSerialization.data(withJSONObject: [payload(context: ["chain": "base-sepolia"])])

        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let log = try #require(decoded.first)

        #expect(log["chain"] as? String == "base-sepolia")
        #expect((log["os"] as? [String: String])?["version"] == "26.0")
        #expect(log["attributes"] == nil)
        #expect(log["tags"] == nil)
        #expect(log["_dd"] == nil)
    }

    @Test func omitsEveryDeviceKeyWhenNoDetailIsAvailable() throws {
        let payload = payload(deviceInfo: DeviceInfoCache())

        #expect(payload["os"] == nil)
        #expect(payload["device"] == nil)
        #expect(payload["network"] == nil)
        #expect(payload["version"] == nil)
        #expect(payload["build_version"] == nil)
        #expect(payload["ddtags"] as? String == "env:production,sdk_version:\(SDKVersion.version)")

        let data = try JSONSerialization.data(withJSONObject: payload)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("unknown"))
    }

    @Test func omitsOnlyTheValuesThatAreMissing() {
        var deviceInfo = Self.makeDeviceInfo(networkConnectionType: nil, cellularTechnology: nil)
        deviceInfo.osBuild = nil
        deviceInfo.appBuild = nil

        let payload = payload(deviceInfo: deviceInfo)

        #expect(payload["os"] as? [String: String] == ["name": "iOS", "version": "26.0"])
        #expect(payload["network"] == nil)
        #expect(payload["build_version"] == nil)
        #expect(payload["version"] as? String == "3.1.4")
        #expect(payload["device"] as? [String: String] == [
            "name": "Tomas iPhone", "model": "iPhone", "brand": "Apple", "architecture": "arm64e"
        ])
    }

    @Test func omitsHostnameAndAppIdWhenTheBundleIdentifierIsMissing() {
        let formatter = DataDogLogFormatter(
            loggerName: Self.LOGGER_NAME, environment: "production", sessionId: Self.SESSION_ID, hostname: nil
        )

        let payload = formatter.payload(
            for: Self.makeEntry(),
            deviceInfo: Self.makeDeviceInfo(),
            threadName: Self.THREAD_NAME
        )

        #expect(payload["hostname"] == nil)
        #expect(payload["logger"] as? [String: String] == [
            "name": Self.LOGGER_NAME, "version": SDKVersion.version, "thread_name": Self.THREAD_NAME
        ])
    }
}
