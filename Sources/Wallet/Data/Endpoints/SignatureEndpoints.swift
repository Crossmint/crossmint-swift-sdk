//
//  SignatureEndpoints.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/05/26.
//

import CrossmintCommonTypes
import Foundation
import Http

extension Endpoint {
    static func createSignature(chainType: ChainType, headers: [String: String] = [:], body: Data) -> Endpoint {
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
        headers: [String: String] = [:],
        body: Data
    ) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)/approvals",
            method: .post,
            headers: headers,
            body: body
        )
    }

    static func fetchSignature(chainType: ChainType, signatureId: String, headers: [String: String] = [:]) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/signatures/\(signatureId)",
            method: .get,
            headers: headers
        )
    }
}
