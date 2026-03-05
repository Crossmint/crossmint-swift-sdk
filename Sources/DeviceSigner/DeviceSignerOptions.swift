//
//  DeviceSignerOptions.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 4/3/26.
//

import Foundation

/// Configuration for the device signer feature.
///
/// When provided via ``WalletOptions/deviceSigner``, the SDK generates a hardware-backed
/// P-256 signing key in the Secure Enclave (or a software fallback on simulators) and
/// registers it as a delegated signer on the wallet. Subsequent transactions are co-signed
/// by this key silently, without requiring an OTP prompt on the same device.
///
/// ```swift
/// let wallet = try await crossmint.wallets.getOrCreateWallet(
///     chain: .polygon,
///     signer: emailSigner,
///     options: WalletOptions(deviceSigner: DeviceSignerOptions(biometricPolicy: .always))
/// )
/// ```
public struct DeviceSignerOptions: Sendable {
    /// The biometric policy applied when the device signing key is used.
    /// Defaults to ``BiometricPolicy/none`` (no prompt required).
    public let biometricPolicy: BiometricPolicy

    /// Creates device signer options.
    ///
    /// - Parameter biometricPolicy: When to require biometric authentication.
    ///   Defaults to ``BiometricPolicy/none``.
    public init(biometricPolicy: BiometricPolicy = .none) {
        self.biometricPolicy = biometricPolicy
    }
}
