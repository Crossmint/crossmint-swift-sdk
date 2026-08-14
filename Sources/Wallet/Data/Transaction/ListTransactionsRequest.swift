import CrossmintCommonTypes

public struct ListTransactionsRequest {
    let chainType: ChainType
    let page: Int
    let perPage: Int
}
