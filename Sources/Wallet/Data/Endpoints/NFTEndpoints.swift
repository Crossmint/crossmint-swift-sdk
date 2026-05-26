import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func walletNFTs(
        chainName: String,
        walletLocator: String,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2022-06-09/wallets/\(chainName):\(walletLocator)/nfts",
            method: .get,
            headers: headers,
            queryItems: queryItems
        )
    }
}
