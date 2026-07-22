//
//  DeviceSignerError.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 4/3/26.
//

import Foundation

/// Errors that can occur during device signer operations.
public enum DeviceSignerError: Error, Sendable {
    /// No key found in storage for the given wallet address.
    case keyNotFound
    /// Key generation failed.
    case keyGenerationFailed
    /// The signer failed to sign the message.
    /// `operation` is the step that failed.
    /// `underlyingError` is the error from CryptoKit or the Security framework.
    case signingFailed(operation: String, underlyingError: Error)
    /// A Keychain operation failed. The associated value is the `OSStatus` error code.
    case storageError(OSStatus)
    /// The message to sign could not be decoded.
    case invalidMessage

    public var code: String {
        switch self {
        case .keyNotFound:          "DEVICE_SIGNER_KEY_NOT_FOUND"
        case .keyGenerationFailed:  "DEVICE_SIGNER_KEY_GENERATION_FAILED"
        case .signingFailed:        "DEVICE_SIGNER_SIGNING_FAILED"
        case .storageError:         "DEVICE_SIGNER_STORAGE_ERROR"
        case .invalidMessage:       "DEVICE_SIGNER_INVALID_MESSAGE"
        }
    }

    public var message: String {
        switch self {
        case .keyNotFound:
            "No device signer key found for this wallet."
        case .keyGenerationFailed:
            "Failed to generate a device signer key."
        case .signingFailed(let operation, let underlyingError):
            "Failed to sign the message with the device signer key. "
                + "\(operation) failed: \(underlyingError)"
        case .storageError(let status):
            "Keychain operation failed with status \(status)."
        case .invalidMessage:
            "The message to sign could not be decoded."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .keyNotFound:
            "The wallet may need to re-register a device signer."
        case .keyGenerationFailed:
            "Ensure the device has sufficient storage and the app has Keychain access."
        case .storageError:
            "Ensure the app has Keychain entitlements and the device is unlocked."
        case .signingFailed:
            "The stored device signer key can no longer sign on this device "
                + "(for example after a device restore or Secure Enclave reset). "
                + "Re-register a device signer for this wallet."
        case .invalidMessage:
            nil
        }
    }

    /// The original error from the underlying signing operation. Returns `nil` if there is no such error.
    public var underlyingError: Error? {
        switch self {
        case .signingFailed(_, let underlyingError): underlyingError
        default: nil
        }
    }
}
