//
//  CreateStellarTransactionRequest.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import Foundation

public struct CreateStellarTransactionRequest: TransactionRequest, Codable {
    private enum CodingKeys: String, CodingKey {
        case params
    }

    private struct Params: Codable {
        let transaction: String
        let signer: String?
    }

    public let transaction: String
    /// Locator of the signer that authorizes the transaction. Omitted when `nil`, so the
    /// backend falls back to the wallet's admin signer.
    public let signer: String?

    public init(transaction: String, signer: String? = nil) {
        self.transaction = transaction
        self.signer = signer
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let params = try container.decode(Params.self, forKey: .params)

        self.transaction = params.transaction
        self.signer = params.signer
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let params = Params(transaction: transaction, signer: signer)
        try container.encode(params, forKey: .params)
    }
}
