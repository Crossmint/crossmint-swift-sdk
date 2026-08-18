//
//  WalletSigner.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 7/13/26.
//

/// A signer registered on a wallet, as returned by ``Wallet/signers()``.
public struct WalletSigner: Sendable, Hashable {
    /// The signer locator. Use ``SignerLocator/value`` for the string form,
    /// e.g. `"email:user@example.com"` or `"device:<pubkey>"`.
    public let locator: SignerLocator

    /// The registration status of this signer on the wallet's chain.
    public let status: SignerStatus
}
