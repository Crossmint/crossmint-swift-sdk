extension EVMWallet {

    /// Registers a new signer on this wallet, choosing how the registration gets approved.
    ///
    /// - Parameters:
    ///   - config: The signer configuration to register.
    ///   - deployImmediately: Whether the registration is approved through an on-chain
    ///     transaction rather than the lazy signature-request flow.
    ///   - approver: The recovery signer that authorizes the registration. See
    ///     ``Wallet/addSigner(_:approver:)``.
    /// - Throws: ``WalletError`` if registration fails.
    public func addSigner(
        _ config: SignerConfig,
        deployImmediately: Bool,
        approver: SignerConfig? = nil
    ) async throws(WalletError) {
        try await registerSigner(config, deployImmediately: deployImmediately, approver: approver)
    }
}
