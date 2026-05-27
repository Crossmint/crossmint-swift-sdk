import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func meWalletTokenTransfer(
        chainType: ChainType,
        tokenLocator: String,
        headers: [String: String] = [:],
        body: Data
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/tokens/\(tokenLocator)/transfers",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func meWalletTransferList(
        chainType: ChainType,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/unstable/wallets/me:\(chainType.rawValue)/transfers",
            method: .get,
            headers: headers,
            queryItems: queryItems
        )
    }
}
