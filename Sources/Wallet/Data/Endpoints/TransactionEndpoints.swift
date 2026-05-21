import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func createTransaction(chainType: ChainType, headers: [String: String] = [:], body: Data) -> Endpoint {
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
        headers: [String: String] = [:],
        body: Data
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)/approvals",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func fetchTransaction(
        chainType: ChainType,
        transactionId: String,
        headers: [String: String] = [:]
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/transactions/\(transactionId)",
            method: .get,
            headers: headers
        )
    }
}
