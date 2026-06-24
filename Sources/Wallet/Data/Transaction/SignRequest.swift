import CrossmintCommonTypes

public struct SignRequest: Sendable {
    let transactionId: String
    let apiRequest: SignRequestApi
    let chainType: ChainType
}
