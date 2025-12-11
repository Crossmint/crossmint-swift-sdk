//
//  TrackingConsent.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 11/12/25.
//

import Foundation

/// Tracking consent states for remote logging (GDPR compliance)
public enum TrackingConsent: Sendable {
    /// The SDK starts collecting and batching the data but does not send it to the remote logging endpoint.
    case pending
    /// The SDK starts collecting the data and sends it to the remote logging endpoint.
    case granted
    /// The SDK does not collect any data for remote logging.
    case notGranted
}
