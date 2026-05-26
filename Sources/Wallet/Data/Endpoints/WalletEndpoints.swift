import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func meWallet(chainType: ChainType, headers: [String: String] = [:]) -> Endpoint {
        Endpoint(path: "/2025-06-09/wallets/me:\(chainType.rawValue)", method: .get, headers: headers)
    }

    static func createMeWallet(headers: [String: String] = [:], body: Data) -> Endpoint {
        Endpoint(path: "/2025-06-09/wallets/me", method: .post, headers: headers, body: body)
    }

    static func fundWallet(address: String, headers: [String: String] = [:], body: Data) -> Endpoint {
        Endpoint(path: "/v1-alpha2/wallets/\(address)/balances", method: .post, headers: headers, body: body)
    }

    static func removeSigner(
        chainType: ChainType,
        encodedLocator: String,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signers/\(encodedLocator)",
            method: .delete,
            headers: headers,
            queryItems: queryItems
        )
    }
}
