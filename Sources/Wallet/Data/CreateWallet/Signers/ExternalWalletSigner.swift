//
//  ExternalWalletSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/09/26.
//

import CrossmintCommonTypes

/// A signer that uses an external wallet, for example a wallet app or a hardware wallet.
///
/// To sign with the external wallet, pass this signer to `useSigner(_:)` on a ``Wallet``.
/// To use the external wallet as a recovery signer, pass this signer when you create a wallet.
///
/// The SDK calls `onSign` each time the wallet needs an approval from this signer.
/// `onSign` receives a message. Sign the message with the external wallet and return the signature.
/// The format of the message and of the signature changes with the chain of the wallet:
/// - EVM: The message is a hex string that starts with `0x`. Decode the hex string.
///   Sign the bytes as an EIP-191 personal message (`personal_sign`).
///   Return the 65-byte signature as a hex string that starts with `0x`.
/// - Solana: The message is a base58 string. Decode the string and sign the bytes with Ed25519.
///   Return the 64-byte signature as a base58 string.
/// - Stellar: The message is a base64 string. Decode the string and sign the bytes with Ed25519.
///   Return the 64-byte signature as a base64 string.
///
/// If the user does not accept the request to sign, throw ``SignerError/cancelled`` from `onSign`.
public struct ExternalWalletSigner: Signer {
    public typealias AdminType = ExternalWalletSignerData

    public let signerType: SignerType = .externalWallet
    public let adminSigner: ExternalWalletSignerData
    private let onSign: @Sendable (String) async throws -> String

    /// Makes a signer for the external wallet at `address`.
    ///
    /// - Parameters:
    ///   - address: The address of the external wallet.
    ///   - onSign: Signs a message with the external wallet and returns the signature.
    public init(address: String, onSign: @escaping @Sendable (String) async throws -> String) {
        self.adminSigner = ExternalWalletSignerData(address: address)
        self.onSign = onSign
    }

    public func initialize(_ service: SmartWalletService?) async throws(SignerError) {}

    public func sign(message: String) async throws(SignerError) -> String {
        do {
            return try await onSign(message)
        } catch let error as SignerError {
            throw error
        } catch is CancellationError {
            throw .cancelled
        } catch {
            throw .signingFailed
        }
    }

    public func approvals(withSignature signature: String) async throws(SignerError) -> [SignRequestApi.Approval] {
        [.keypair(signer: adminSigner.locator, signature: signature)]
    }
}
