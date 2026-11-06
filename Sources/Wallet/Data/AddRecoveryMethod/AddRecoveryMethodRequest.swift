//
//  AddRecoveryMethodRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 25/09/26.
//

import CrossmintCommonTypes
import Foundation
import Http

struct AddRecoveryMethodBody: Encodable {
    let recoveryMethods: AdminSignerRequestApiModel
    let approver: String
    let chain: String?

    enum CodingKeys: String, CodingKey {
        case recoveryMethods
        case approver
        case chain
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(recoveryMethods, forKey: .recoveryMethods)
        try container.encode(approver, forKey: .approver)
        try container.encodeIfPresent(chain, forKey: .chain)
    }
}

struct AddRecoveryMethodResponse<Transaction: Decodable>: Decodable {
    let tx: Transaction
}

extension Endpoint {
    static func addRecoveryMethod(chainType: ChainType, body: Data) -> Endpoint {
        Endpoint(
            path: "/2025-06-09/wallets/me:\(chainType.rawValue)/recovery-methods",
            method: .post,
            body: body
        )
    }
}
