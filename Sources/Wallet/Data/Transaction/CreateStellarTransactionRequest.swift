//
//  CreateStellarTransactionRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import Foundation

public struct CreateStellarTransactionRequest: TransactionRequest, Codable {
    public let transaction: String

    public init(transaction: String) {
        self.transaction = transaction
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let params = Params(transaction: transaction)
        try container.encode(params, forKey: .params)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let params = try container.decode(Params.self, forKey: .params)

        self.transaction = params.transaction
    }

    private enum CodingKeys: String, CodingKey {
        case params
    }

    private struct Params: Codable {
        let transaction: String
    }
}
