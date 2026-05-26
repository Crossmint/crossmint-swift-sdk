//
//  TransactionService.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/05/26.
//

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
}
