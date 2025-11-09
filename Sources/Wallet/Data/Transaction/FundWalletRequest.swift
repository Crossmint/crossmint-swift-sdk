import CrossmintCommonTypes

public struct FundWalletRequest {
    let token: String
    let amount: Int
    let chain: String
    let address: Address
}
