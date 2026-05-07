import CrossmintAuth
import CrossmintCommonTypes
import CrossmintService
import Http

struct DefaultTransactionService: TransactionService {
    let crossmintService: CrossmintService
    let jsonCoder: JSONCoder
    let authManager: AuthManager

    var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else { return [:] }
            return ["Authorization": "Bearer \(jwt)"]
        }
    }

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
