import CrossmintCommonTypes
import CrossmintService

public protocol BalanceService: AuthenticatedService, Sendable {
    func getBalance(
        _ params: GetBalanceQueryParams
    ) async throws(WalletError) -> Balances
}
