import CrossmintAuth
import CrossmintService
import Http

protocol AuthManagerBacked: AuthenticatedService {
    var authManager: AuthManager { get }
}

extension AuthManagerBacked {
    var authHeaders: [String: String] {
        get async {
            guard let jwt = await authManager.jwt else { return [:] }
            return ["Authorization": "Bearer \(jwt)"]
        }
    }
}

protocol TransactionExecuting: Sendable {
    var crossmintService: CrossmintService { get }
    var jsonCoder: JSONCoder { get }
}

extension TransactionExecuting {
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
