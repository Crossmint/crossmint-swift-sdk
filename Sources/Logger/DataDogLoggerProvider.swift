//
//  DataDogLoggerProvider.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import DatadogCore
import DatadogLogs

final class DataDogLoggerProvider: LoggerProvider {
    private let logger: LoggerProtocol
    private let service: String

    init(service: String, clientToken: String, environment: String) {
        self.service = service

        Self.setupDataDogIfNeeded(clientToken: clientToken, environment: environment)

        logger = DatadogLogs.Logger.create(
            with: .init(
                name: service,
                networkInfoEnabled: true,
                bundleWithRumEnabled: false,
                remoteSampleRate: 100
            )
        )
    }

    func debug(_ message: String, attributes: [String: any Encodable]?) {
        logger.debug(message, attributes: buildAttributes(attributes))
    }

    func error(_ message: String, attributes: [String: any Encodable]?) {
        logger.error(message, attributes: buildAttributes(attributes))
    }

    func info(_ message: String, attributes: [String: any Encodable]?) {
        logger.info(message, attributes: buildAttributes(attributes))
    }

    func warn(_ message: String, attributes: [String: any Encodable]?) {
        logger.warn(message, attributes: buildAttributes(attributes))
    }

    private func buildAttributes(_ attributes: [String: any Encodable]?) -> [String: Encodable] {
        var loggerAttributes: [String: Encodable] = [
            "service": service,
            "platform": "ios"
        ]

        if let attributes {
            loggerAttributes.merge(attributes) { _, new in new }
        }

        return loggerAttributes
    }

    private static func setupDataDogIfNeeded(clientToken: String, environment: String) {
        guard !DataDogConfig.isDataDogInitialized else { return }

        Datadog.initialize(
            with: Datadog.Configuration(
                clientToken: clientToken,
                env: environment,
                service: "crossmint-ios-sdk"
            ),
            trackingConsent: DataDogConfig.datadogConsent(for: DataDogConfig.trackingConsent)
        )

        Logs.enable()

        DataDogConfig.markDataDogInitialized()
    }
}
