import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

extension DefaultSmartWalletService {
    public func createTransaction(
        _ request: CreateTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let chainType = request.chainType
        let apiRequest = request.request

        let bodyData = try jsonCoder.encodeRequest(apiRequest, errorType: TransactionError.self)

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions",
            method: .post,
            headers: await authHeaders,
            body: bodyData
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }

    public func signTransaction(
        _ request: SignRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let chainType = request.chainType
        let transactionId = request.transactionId
        let apiRequest = request.apiRequest

        let bodyData = try jsonCoder.encodeRequest(apiRequest, errorType: TransactionError.self)

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)/approvals",
            method: .post,
            headers: await authHeaders,
            body: bodyData
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }

    public func fetchTransaction(
        _ fetchTransactionRequest: FetchTransactionRequest
    ) async throws(TransactionError) -> any TransactionApiModel {
        let transactionId = fetchTransactionRequest.transactionId
        let chainType = fetchTransactionRequest.chainType

        let endpoint = Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)",
            method: .get,
            headers: await authHeaders
        )

        return try await executeTransactionRequest(
            endpoint: endpoint,
            mapping: chainType.mappingType
        )
    }
}
