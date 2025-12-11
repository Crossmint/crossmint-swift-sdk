//
//  DataDogConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation
import DatadogCore

public enum DataDogConfig {
    static let clientToken = "pub946d87ea0c2cc02431c15e9446f776fc"

    private(set) nonisolated(unsafe) static var environment: String = "production"
    private(set) nonisolated(unsafe) static var trackingConsent: TrackingConsent = .notGranted
    private(set) nonisolated(unsafe) static var isDataDogInitialized: Bool = false

    public static func configure(environment: String) {
        self.environment = environment
    }

    /// Sets or updates the tracking consent for remote logging
    /// - Parameter consent: The new tracking consent state
    /// - Note: When changing from pending to granted, all batched data will be sent.
    ///         When changing from pending to notGranted, all batched data will be wiped.
    ///         Safe to call before or after DataDog initialization.
    public static func setTrackingConsent(_ consent: TrackingConsent) {
        self.trackingConsent = consent

        // Only update DataDog if it's already initialized
        if isDataDogInitialized {
            Datadog.set(trackingConsent: datadogConsent(for: consent))
        }
    }

    static func markDataDogInitialized() {
        isDataDogInitialized = true
    }

    static func datadogConsent(for consent: TrackingConsent) -> DatadogCore.TrackingConsent {
        switch consent {
        case .pending:
            return .pending
        case .granted:
            return .granted
        case .notGranted:
            return .notGranted
        }
    }
}
