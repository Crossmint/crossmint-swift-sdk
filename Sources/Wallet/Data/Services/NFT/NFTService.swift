import CrossmintCommonTypes
import CrossmintService

public protocol NFTService: AuthenticatedService, Sendable {
    func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT]
}
