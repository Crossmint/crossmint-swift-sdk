import CrossmintCommonTypes
import CrossmintService
import Http

extension DefaultSmartWalletService {
    public func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT] {
        let response: [NFTApiModel] = try await crossmintService.executeRequest(
            Endpoint(
                path: "/2022-06-09/wallets/\(params.chain.name):\(params.walletLocator.value)/nfts",
                method: .get,
                headers: await authHeaders,
                queryItems: [
                    .init(name: "page", value: "\(params.page)"),
                    .init(name: "perPage", value: "\(params.perPage)")
                ]
            ),
            errorType: WalletError.self
        )
        return response.map { .map($0) }
    }
}
