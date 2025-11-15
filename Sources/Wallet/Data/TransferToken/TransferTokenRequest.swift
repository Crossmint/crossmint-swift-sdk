import CrossmintCommonTypes

public struct TransferTokenRequest: Encodable {
    let tokenLocator: TransferTokenLocator
    let recipient: TransferTokenRecipient
    let chainType: ChainType
    let amount: String
}
