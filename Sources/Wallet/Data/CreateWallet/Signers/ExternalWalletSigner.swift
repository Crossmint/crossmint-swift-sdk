//
//  ExternalWalletSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 24/09/26.
//

import CrossmintCommonTypes

/// A signer that uses an external wallet, for example a wallet app or a hardware wallet.
///
/// To use the external wallet as a recovery signer, pass this signer when you create a wallet.
/// To sign with the external wallet, pass ``SignerConfig/externalWallet(_:onSign:)``
/// to ``Wallet/useSigner(_:)``.
///
/// For the message that `onSign` receives and the signature that it returns,
/// see ``SignerConfig/externalWallet(_:onSign:)``.
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
    ///     See ``SignerConfig/externalWallet(_:onSign:)``.
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
