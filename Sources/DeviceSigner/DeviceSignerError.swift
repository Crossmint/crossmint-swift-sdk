//
//  DeviceSignerError.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 4/3/26.
//

import Foundation

/// Errors that can occur during device signer operations.
public enum DeviceSignerError: Error, Sendable {
    /// Secure Enclave is not available on this device.
    case hardwareUnavailable
    /// No key found in storage for the given wallet address.
    case keyNotFound
    /// Key generation failed.
    case keyGenerationFailed
    /// Signing the message failed.
    case signingFailed
    /// A Keychain operation failed. The associated value is the `OSStatus` error code.
    case storageError(OSStatus)
    /// The message to sign could not be decoded.
    case invalidMessage

    /// A machine-readable code identifying the error.
    /// Intended to conform to `CrossmintError.code` when that protocol is introduced.
    public var code: String {
        switch self {
        case .hardwareUnavailable:  "DEVICE_SIGNER_HARDWARE_UNAVAILABLE"
        case .keyNotFound:          "DEVICE_SIGNER_KEY_NOT_FOUND"
        case .keyGenerationFailed:  "DEVICE_SIGNER_KEY_GENERATION_FAILED"
        case .signingFailed:        "DEVICE_SIGNER_SIGNING_FAILED"
        case .storageError:         "DEVICE_SIGNER_STORAGE_ERROR"
        case .invalidMessage:       "DEVICE_SIGNER_INVALID_MESSAGE"
        }
    }

    /// Human-readable guidance on how to recover from the error, if applicable.
    /// Intended to conform to `CrossmintError.recoverySuggestion` when that protocol is introduced.
    public var recoverySuggestion: String? {
        switch self {
        case .hardwareUnavailable:
            "Secure Enclave is not available on this device. The SDK will fall back to software key storage."
        case .keyNotFound:
            "The device signer key for this wallet was not found. The wallet may need to re-register a device signer."
        case .keyGenerationFailed:
            "Key generation failed. Ensure the device has sufficient storage and the app has Keychain access."
        case .storageError:
            "A Keychain error occurred. Ensure the app has Keychain entitlements and the device is unlocked."
        case .signingFailed, .invalidMessage:
            nil
        }
    }
}
