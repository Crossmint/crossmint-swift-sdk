import CrossmintCommonTypes

public struct CreateTransactionRequest: Sendable {
    let request: any TransactionRequest
    let chainType: ChainType
}
