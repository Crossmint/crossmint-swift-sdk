extension EVMWallet {

    /// Registers a new signer on this wallet, choosing how the registration gets approved.
    ///
    /// - Parameters:
    ///   - config: The signer configuration to register.
    ///   - deployImmediately: Whether the registration is approved through an on-chain
    ///     transaction rather than the lazy signature-request flow. When a quorum approves, pass `true`.
    /// - Returns: When a quorum approves, the transaction that adds the signer. Each member then approves it
    ///   with ``Wallet/approve(transactionId:)``. Otherwise `nil`.
    /// - Throws: ``WalletError`` if registration fails, or if a quorum approves and `deployImmediately` is `false`.
    @discardableResult
    public func addSigner(_ config: SignerConfig, deployImmediately: Bool) async throws(WalletError) -> Transaction? {
        try await registerSigner(config, deployImmediately: deployImmediately)
    }
}
