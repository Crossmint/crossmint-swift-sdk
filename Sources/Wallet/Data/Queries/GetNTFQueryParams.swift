import CrossmintCommonTypes
import Foundation

public struct GetNTFQueryParams {
    let walletLocator: WalletLocator
    let chain: AnyChain
    let page: Int
    let perPage: Int

    public init(
        walletLocator: WalletLocator,
        chain: AnyChain,
        page: Int,
        perPage: Int
    ) {
        self.walletLocator = walletLocator
        self.chain = chain
        self.page = page
        self.perPage = perPage
    }
}
