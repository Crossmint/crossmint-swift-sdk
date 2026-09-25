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
