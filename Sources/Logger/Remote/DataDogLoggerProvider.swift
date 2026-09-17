//
//  DataDogLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

actor DataDogLoggerProvider: LoggerProvider {
    // MARK: - Constants
    private let batchSize = 10
    private let batchTimeoutSeconds: TimeInterval = 5.0

    // MARK: - Configuration
    private let formatter: DataDogLogFormatter
    private let intakeUrl: String

    // MARK: - State
    private var batchQueue: [LogEntry] = []
    private var batchTask: Task<Void, Never>?
    private var deviceInfo: DeviceInfoCache?

    // MARK: - Cached device info (single capture task)
    private static let captureTask: Task<DeviceInfoCache, Never> = Task {
        await DeviceInfoCache.capture()
    }

    // MARK: - Date Formatter (reused for performance)
    private nonisolated(unsafe) static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Initialization
    init(service: String, clientToken: String, environment: String) {
        self.formatter = DataDogLogFormatter(
            loggerName: service,
            environment: environment,
            sessionId: Self.generateSessionId(),
            hostname: Bundle.main.bundleIdentifier
        )

        let datadogUrl = "https://http-intake.logs.datadoghq.com/v1/input/\(clientToken)"
        let encodedUrl = datadogUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? datadogUrl
        self.intakeUrl = "https://telemetry.crossmint.com/dd?ddforward=\(encodedUrl)"

        Self.setupLifecycleObservers(provider: self)

        Task {
            await self.captureDeviceInfo()
        }
    }

    private func captureDeviceInfo() async {
        self.deviceInfo = await Self.captureTask.value
    }

    // MARK: - LoggerProvider Protocol
    nonisolated func debug(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .debug, message: message, attributes: attrs.value)
        }
    }

    nonisolated func error(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .error, message: message, attributes: attrs.value)
        }
    }

    nonisolated func info(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .info, message: message, attributes: attrs.value)
        }
    }

    nonisolated func warning(_ message: String, attributes: [String: Encodable]?) {
        let attrs = UnsafeSendableAttributes(value: attributes)
        Task.detached { [weak self] in
            await self?.write(level: .warning, message: message, attributes: attrs.value)
        }
    }

    // MARK: - Core Logic (actor-isolated)
    private func write(level: LogLevel, message: String, attributes: [String: Encodable]?) {
        let entry = LogEntry(
            level: level,
            message: formatMessage(message, attributes: attributes),
            timestamp: Self.iso8601Formatter.string(from: Date()),
            context: attributes ?? [:]
        )

        batchQueue.append(entry)

        if batchQueue.count >= batchSize {
            flush()
        } else {
            scheduleBatchTimeout()
        }
    }

    private func scheduleBatchTimeout() {
        batchTask?.cancel()

        let timeout = batchTimeoutSeconds
        batchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.flush()
        }
    }

    func flush() {
        batchTask?.cancel()
        batchTask = nil

        guard !batchQueue.isEmpty else { return }

        let batch = batchQueue
        batchQueue.removeAll()

        Task {
            await sendBatch(batch)
        }
    }

    private func sendBatch(_ batch: [LogEntry]) async {
        let logs = batch.map { entry in
            formatter.payload(for: entry, deviceInfo: deviceInfo ?? .empty, threadName: Self.getThreadName())
        }

        do {
            guard let url = URL(string: intakeUrl) else {
                print("[SDK Logger] Invalid intake URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: logs)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                print("[SDK Logger] DataDog proxy returned error: \(httpResponse.statusCode)")
            }
        } catch {
            print("[SDK Logger] Error sending logs to DataDog: \(error)")
        }
    }

    // MARK: - Formatting
    private func formatMessage(_ message: String, attributes: [String: Encodable]?) -> String {
        guard let attributes = attributes, !attributes.isEmpty else {
            return message
        }

        let attributeStrings = attributes.map { key, value in
            "\(key)=\(value)"
        }.sorted().joined(separator: " ")

        return "\(message) \(attributeStrings)"
    }

    private static func getThreadName() -> String {
        if Thread.isMainThread {
            return "main"
        }
        if let name = Thread.current.name, !name.isEmpty {
            return name
        }
        return "background"
    }

    // MARK: - Session ID Generation
    private static func generateSessionId() -> String {
        var bytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Lifecycle Management
    private static func setupLifecycleObservers(provider: DataDogLoggerProvider) {
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.flush() }
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { await provider.flush() }
        }
        #endif
    }
}
