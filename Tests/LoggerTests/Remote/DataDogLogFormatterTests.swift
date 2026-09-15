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
    static let ENVIRONMENT = "production"
    static let SESSION_ID = "0123456789abcdef"
    static let HOSTNAME = "com.example.app"
    static let THREAD_NAME = "main"

    let formatter = DataDogLogFormatter(
        loggerName: LOGGER_NAME,
        environment: ENVIRONMENT,
        sessionId: SESSION_ID,
        hostname: HOSTNAME
    )

    let deviceInfo = makeDeviceInfo()

    static func makeDeviceInfo(
        networkConnectionType: String = "cellular",
        cellularTechnology: String? = "5G"
    ) -> DeviceInfoCache {
        DeviceInfoCache(
            model: "iPhone",
            deviceName: "Tomas iPhone",
            osName: "iOS",
            osVersion: "26.0",
            osBuild: "23A340",
            architecture: "arm64e",
            appVersion: "3.1.4",
            appBuild: "42",
            networkConnectionType: networkConnectionType,
            cellularTechnology: cellularTechnology
        )
    }

    func makeEntry(
        level: LogLevel = .info,
        message: String = "wallet created",
        context: [String: Encodable] = [:]
    ) -> LogEntry {
        LogEntry(level: level, message: message, timestamp: "2026-09-15T10:00:00.000Z", context: context)
    }

    func makePayload(entry: LogEntry? = nil) -> [String: Any] {
        formatter.payload(for: entry ?? makeEntry(), deviceInfo: deviceInfo, threadName: Self.THREAD_NAME)
    }

    @Test func sendsTagsAsCommaSeparatedDdtagsString() throws {
        let ddtags = try #require(makePayload()["ddtags"] as? String)

        #expect(ddtags == "env:production,sdk_version:\(SDKVersion.version),version:3.1.4")
    }

    @Test func sendsSourceAsTopLevelDdsource() {
        #expect(makePayload()["ddsource"] as? String == "ios")
    }

    @Test func sendsReservedAttributesAtTopLevel() {
        let payload = makePayload()

        #expect(payload["message"] as? String == "wallet created")
        #expect(payload["status"] as? String == "info")
        #expect(payload["service"] as? String == "crossmint-ios-sdk")
        #expect(payload["hostname"] as? String == Self.HOSTNAME)
        #expect(payload["timestamp"] as? String == "2026-09-15T10:00:00.000Z")
        #expect(payload["dd-session_id"] as? String == Self.SESSION_ID)
        #expect(payload["platform"] as? String == "ios")
        #expect(payload["version"] as? String == "3.1.4")
        #expect(payload["build_version"] as? String == "42")
    }

    @Test func sendsOsAsTopLevelObject() throws {
        let os = try #require(makePayload()["os"] as? [String: String])

        #expect(os == ["name": "iOS", "version": "26.0", "build": "23A340"])
    }

    @Test func sendsDeviceAsTopLevelObject() throws {
        let device = try #require(makePayload()["device"] as? [String: String])

        #expect(device == ["name": "Tomas iPhone", "model": "iPhone", "brand": "Apple", "architecture": "arm64e"])
    }

    @Test func sendsLoggerAsTopLevelObject() throws {
        let logger = try #require(makePayload()["logger"] as? [String: String])

        #expect(logger == [
            "name": Self.LOGGER_NAME,
            "version": SDKVersion.version,
            "thread_name": Self.THREAD_NAME,
            "app_id": Self.HOSTNAME
        ])
    }

    @Test func sendsNetworkClientAsTopLevelObject() throws {
        let network = try #require(makePayload()["network"] as? [String: Any])
        let client = try #require(network["client"] as? [String: String])

        #expect(client == ["type": "cellular", "cellular_technology": "5G"])
    }

    @Test func omitsCellularTechnologyWhenUnavailable() throws {
        let wifiInfo = Self.makeDeviceInfo(networkConnectionType: "wifi", cellularTechnology: nil)

        let payload = formatter.payload(for: makeEntry(), deviceInfo: wifiInfo, threadName: Self.THREAD_NAME)
        let network = try #require(payload["network"] as? [String: Any])
        let client = try #require(network["client"] as? [String: String])

        #expect(client == ["type": "wifi"])
    }

    @Test func sendsContextKeysAtTopLevel() {
        let entry = makeEntry(context: ["chain": "base-sepolia", "attempt": 2])

        let payload = makePayload(entry: entry)

        #expect(payload["chain"] as? String == "base-sepolia")
        #expect(payload["attempt"] as? Int == 2)
    }

    @Test func keepsReservedKeysWhenContextUsesTheSameName() {
        let entry = makeEntry(context: ["status": "pending", "service": "other"])

        let payload = makePayload(entry: entry)

        #expect(payload["status"] as? String == "info")
        #expect(payload["service"] as? String == "crossmint-ios-sdk")
    }

    @Test func dropsLegacyAttributesAndTagsWrappers() {
        let payload = makePayload(entry: makeEntry(context: ["chain": "base-sepolia"]))

        #expect(payload["attributes"] == nil)
        #expect(payload["tags"] == nil)
        #expect(payload["_dd"] == nil)
    }

    @Test(arguments: [
        (LogLevel.debug, "info"),
        (LogLevel.info, "info"),
        (LogLevel.warning, "warn"),
        (LogLevel.error, "error"),
        (LogLevel.silent, "none")
    ])
    func mapsLevelToDatadogStatus(level: LogLevel, status: String) {
        #expect(makePayload(entry: makeEntry(level: level))["status"] as? String == status)
    }

    @Test func serializesToJson() throws {
        let entry = makeEntry(context: ["chain": "base-sepolia", "attempt": 2])

        let data = try JSONSerialization.data(withJSONObject: [makePayload(entry: entry)])
        let decoded = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let log = try #require(decoded.first)

        #expect(log["ddtags"] as? String == "env:production,sdk_version:\(SDKVersion.version),version:3.1.4")
        #expect(log["chain"] as? String == "base-sepolia")
        #expect((log["os"] as? [String: String])?["version"] == "26.0")
    }
}
