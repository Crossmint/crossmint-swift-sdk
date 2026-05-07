import CrossmintCommonTypes
import CrossmintService

public protocol TransferService: AuthenticatedService, Sendable {
    func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    // Uses the /unstable/ API prefix — the response shape may change without notice.
    func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult
}
