public struct GetTransationQueryParams {
    let walletLocator: WalletLocator
    let transactionId: String

    public init(walletLocator: WalletLocator, transactionId: String) {
        self.walletLocator = walletLocator
        self.transactionId = transactionId
    }
}
