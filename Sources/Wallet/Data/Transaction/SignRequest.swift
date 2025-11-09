import CrossmintCommonTypes

public struct SignRequest {
    let transactionId: String
    let apiRequest: SignRequestApi
    let chainType: ChainType
}
