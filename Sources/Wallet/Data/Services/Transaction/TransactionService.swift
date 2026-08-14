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
        _ request: ListTransactionsRequest
    ) async throws(TransactionError) -> [Transaction]
}
