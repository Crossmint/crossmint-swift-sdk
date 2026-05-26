import CrossmintCommonTypes
import CrossmintService
import Http

struct DefaultTransactionService: TransactionService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder

    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let bodyData = try jsonCoder.encodeRequest(request.request, errorType: TransactionError.self)
        let endpoint = Endpoint.createTransaction(
            chainType: request.chainType,
            body: bodyData
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let bodyData = try jsonCoder.encodeRequest(request.apiRequest, errorType: TransactionError.self)
        let endpoint = Endpoint.approveTransaction(
            chainType: request.chainType,
            transactionId: request.transactionId,
            body: bodyData
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let endpoint = Endpoint.fetchTransaction(
            chainType: request.chainType,
            transactionId: request.transactionId
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    private func executeTransactionRequest<T: WalletTypeTransactionMapping>(
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
