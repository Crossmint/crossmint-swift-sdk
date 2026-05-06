import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    // MARK: - Wallet Core

    static func meWallet(chainType: ChainType, headers: [String: String]) -> Endpoint {
        Endpoint(path: "/2025-06-09/wallets/me:\(chainType.rawValue)", method: .get, headers: headers)
    }

    static func createMeWallet(headers: [String: String], body: Data) -> Endpoint {
        Endpoint(path: "/2025-06-09/wallets/me", method: .post, headers: headers, body: body)
    }

    static func fundWallet(address: String, headers: [String: String], body: Data) -> Endpoint {
        Endpoint(path: "/v1-alpha2/wallets/\(address)/balances", method: .post, headers: headers, body: body)
    }

    static func removeSigner(
        chainType: ChainType,
        encodedLocator: String,
        headers: [String: String],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signers/\(encodedLocator)",
            method: .delete,
            headers: headers,
            queryItems: queryItems
        )
    }

    // MARK: - Transactions

    static func createTransaction(chainType: ChainType, headers: [String: String], body: Data) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func approveTransaction(
        chainType: ChainType,
        transactionId: String,
        headers: [String: String],
        body: Data
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)/approvals",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func fetchTransaction(chainType: ChainType, transactionId: String, headers: [String: String]) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)",
            method: .get,
            headers: headers
        )
    }

    // MARK: - Balance

    static func walletBalances(
        walletLocator: String,
        headers: [String: String],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/\(walletLocator)/balances",
            method: .get,
            headers: headers,
            queryItems: queryItems
        )
    }

    // MARK: - NFTs

    static func walletNFTs(
        chainName: String,
        walletLocator: String,
        headers: [String: String],
        queryItems: [URLQueryItem]
    ) -> Endpoint {
        Endpoint(
            path: "/2022-06-09/wallets/\(chainName):\(walletLocator)/nfts",
            method: .get,
            headers: headers,
            queryItems: queryItems
        )
    }

    // MARK: - Signatures

    static func createSignature(chainType: ChainType, headers: [String: String], body: Data) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func approveSignature(
        chainType: ChainType,
        signatureId: String,
        headers: [String: String],
        body: Data
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)/approvals",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func fetchSignature(chainType: ChainType, signatureId: String, headers: [String: String]) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)",
            method: .get,
            headers: headers
        )
    }

    // MARK: - Transfers

    static func meWalletTokenTransfer(
        chainType: ChainType,
        tokenLocator: String,
        headers: [String: String],
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
        headers: [String: String],
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
