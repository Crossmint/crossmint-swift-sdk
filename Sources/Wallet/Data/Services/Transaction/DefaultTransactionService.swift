import CrossmintCommonTypes
import CrossmintService
import Http
import Logger

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

    func listTransactions(
        chainType: ChainType
    ) async throws(TransactionError) -> [Transaction] {
        Logger.smartWallet.info(LogEvents.apiListTransactionsStart, attributes: [
            "chain": chainType.rawValue
        ])
        let endpoint = Endpoint.listTransactions(chainType: chainType)
        do {
            let models = try await executeTransactionListRequest(
                endpoint: endpoint,
                mapping: chainType.mappingType
            )
            let transactions = models.compactMap { $0.toDomain() }

            if transactions.count != models.count {
                Logger.smartWallet.warning(LogEvents.apiListTransactionsDropped, attributes: [
                    "dropped": "\(models.count - transactions.count)"
                ])
            }

            Logger.smartWallet.info(LogEvents.apiListTransactionsSuccess, attributes: [
                "count": "\(transactions.count)"
            ])
            return transactions
        } catch {
            Logger.smartWallet.warning(LogEvents.apiListTransactionsError, attributes: ["error": "\(error)"])
            throw error
        }
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
            throw TransactionError.transactionGeneric("Failed to decode transaction response: \(error)")
        }
    }

    private func executeTransactionListRequest<T: WalletTypeTransactionMapping>(
        endpoint: Endpoint,
        mapping: T.Type
    ) async throws(TransactionError) -> [any TransactionApiModel] {
        let data = try await crossmintService.executeRequestForRawData(
            endpoint,
            errorType: TransactionError.self
        )
        do {
            let response = try jsonCoder.decode(TransactionListApiModel<T.APIModel>.self, from: data)
            if !response.decodingErrors.isEmpty {
                Logger.smartWallet.warning(LogEvents.apiListTransactionsRowDecodeError, attributes: [
                    "dropped": "\(response.decodingErrors.count)",
                    "errors": response.decodingErrors.map { "\($0)" }.joined(separator: "; ")
                ])
            }
            return response.transactions
        } catch {
            throw TransactionError.transactionGeneric("Failed to decode transaction list response: \(error)")
        }
    }
}
