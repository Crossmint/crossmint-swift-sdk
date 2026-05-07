import CrossmintCommonTypes
import CrossmintService

public protocol TransferService: AuthenticatedService, Sendable {
    func transferToken(
        _ request: TransferTokenRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func listTransfers(
        _ params: ListTransfersQueryParams
    ) async throws(WalletError) -> TransferListResult
}
