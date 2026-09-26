import CrossmintCommonTypes

/// A recovery method of a wallet, with its install status.
///
/// A recovery method can recover the wallet only when its ``status`` is ``SignerStatus/active``.
///
/// - ``SignerStatus/active``: the signer is installed on the wallet.
/// - ``SignerStatus/awaitingApproval``: the install waits for approval from a signer of the wallet.
/// - ``SignerStatus/pending``: the install is in progress. Get the wallet again later to see the new status.
/// - ``SignerStatus/failed``: the install did not complete. The signer cannot recover the wallet.
/// - ``SignerStatus/unknown``: the wallet does not give a status for this signer.
///   EVM wallets always give this value.
public struct RecoveryMethod: Sendable {
    /// The signer that can recover the wallet.
    public let signer: any AdminSignerData
    /// The install status of ``signer`` on the wallet.
    public let status: SignerStatus

    public init(signer: any AdminSignerData, status: SignerStatus = .unknown) {
        self.signer = signer
        self.status = status
    }
}
