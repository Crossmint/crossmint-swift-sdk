//
//  BiometricPolicy.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 3/3/26.
//

import Foundation

/// Determines when biometric authentication is required to use the device signing key.
public enum BiometricPolicy: Sendable {
    /// No biometric prompt. The key is accessible whenever the device is unlocked.
    case none
    /// Require Face ID or Touch ID on every signing operation.
    case always
}
