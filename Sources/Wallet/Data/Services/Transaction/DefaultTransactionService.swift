import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Http

struct DefaultTransactionService: TransactionService, AuthManagerProviding, TransactionRequestExecuting {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder
    let authManager: AuthManager

    func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let bodyData = try jsonCoder.encodeRequest(request.request, errorType: TransactionError.self)
        let endpoint = Endpoint.createTransaction(
            chainType: request.chainType,
            headers: await authHeaders,
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
            headers: await authHeaders,
            body: bodyData
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }

    func fetchTransaction(
        _ request: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let endpoint = Endpoint.fetchTransaction(
            chainType: request.chainType,
            transactionId: request.transactionId,
            headers: await authHeaders
        )
        return try await executeTransactionRequest(endpoint: endpoint, mapping: request.chainType.mappingType)
    }
}
