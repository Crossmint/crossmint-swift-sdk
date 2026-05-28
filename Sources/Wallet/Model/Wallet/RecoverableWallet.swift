/// A wallet that can check and restore its admin signer.
///
/// Most callers only need `Wallet`. Use `RecoverableWallet` when you need
/// to manage signers — adding new ones, switching the active one, or
/// recovering access after the original signer was lost.
public protocol RecoverableWallet: Wallet {
    /// Returns `true` when the wallet's admin signer is no longer accessible on this device.
    func needsRecovery() async -> Bool

    /// Registers a new signer on the wallet.
    func addSigner(_ config: SignerConfig) async throws

    /// Switches the active signer without registering a new one.
    func useSigner(_ config: SignerConfig) async throws

    /// Initiates the recovery flow using a backup signer.
    func recover() async throws
}
