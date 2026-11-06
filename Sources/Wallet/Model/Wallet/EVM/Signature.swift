//
//  Signature.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 06/11/26.
//

/// The result of a signature request on an EVM wallet.
///
/// Returned by ``EVMWallet/signMessage(_:signer:isSmartWalletSignature:prepareOnly:)``,
/// ``EVMWallet/signTypedData(_:signer:isSmartWalletSignature:prepareOnly:)`` and
/// ``EVMWallet/approve(signatureId:)``.
public struct Signature: Sendable {
    /// The Crossmint signature ID. Approve a pending request with ``EVMWallet/approve(signatureId:)``.
    public let id: String
    /// The signature. The value is `nil` until every required signer approves the request.
    public let signature: String?
}
