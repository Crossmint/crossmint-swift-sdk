public protocol BalanceService: Sendable {
    func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances
}
