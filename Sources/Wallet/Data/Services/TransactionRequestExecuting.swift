import CrossmintService
import Http

protocol TransactionRequestExecuting {
    var crossmintService: CrossmintService { get }
    var jsonCoder: JSONCoder { get }
}

extension TransactionRequestExecuting {
    func executeTransactionRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> any TransactionApiModel {
        let data = try await crossmintService.executeRequestForRawData(
            endpoint,
            errorType: TransactionError.self
        )
        do {
            return try jsonCoder.decode(T.APIModel.self, from: data)
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction response")
        }
    }
}
