public protocol NFTService: Sendable {
    func getNFTs(
        _ params: GetNTFQueryParams
    ) async throws(WalletError) -> [NFT]
}
