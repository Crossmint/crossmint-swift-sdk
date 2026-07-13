import CrossmintCommonTypes

public protocol TransactionService: Sendable {
    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel

    func listTransactions(
        chainType: ChainType
    ) async throws(TransactionError) -> [any TransactionApiModel]
}
