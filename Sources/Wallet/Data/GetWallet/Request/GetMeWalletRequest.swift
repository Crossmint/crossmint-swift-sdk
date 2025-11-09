import CrossmintCommonTypes

public struct GetMeWalletRequest: Encodable {
    let chainType: ChainType

    public init(chainType: ChainType) {
        self.chainType = chainType
    }
}
