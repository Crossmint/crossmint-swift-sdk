import CrossmintCommonTypes
import CrossmintService
import Foundation
import Http

extension DefaultSmartWalletService {
    public func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT] {
        let queryItems: [URLQueryItem] = [
            .init(name: "page", value: "\(params.page)"),
            .init(name: "perPage", value: "\(params.perPage)")
        ]
        let response: [NFTApiModel] = try await crossmintService.executeRequest(
            Endpoint.walletNFTs(
                chainName: params.chain.name,
                walletLocator: params.walletLocator.value,
                headers: await authHeaders,
                queryItems: queryItems
            ),
            errorType: WalletError.self
        )
        return response.map { NFT.map($0) }
    }
}
