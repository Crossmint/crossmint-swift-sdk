//
//  DataDogConfig.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 2/12/25.
//

import Foundation

public enum DataDogConfig {
    static let clientToken = "pub946d87ea0c2cc02431c15e9446f776fc"

    private(set) nonisolated(unsafe) static var environment: String = "production"
    private(set) nonisolated(unsafe) static var trackingConsent: TrackingConsent = .notGranted

    public static func configure(environment: String) {
        self.environment = environment
    }

    /// Sets or updates the tracking consent for remote logging
    /// - Parameter consent: The new tracking consent state
    /// - Note: Data batched while consent was pending is sent with the next batch once consent is granted,
    ///         and is discarded if consent is denied. Safe to call at any point in the SDK lifecycle.
    public static func setTrackingConsent(_ consent: TrackingConsent) {
        self.trackingConsent = consent
    }
}
