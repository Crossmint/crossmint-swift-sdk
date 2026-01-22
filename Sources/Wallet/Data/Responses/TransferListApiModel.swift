//
//  TransferListApiModel.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 21/01/26.
//

import CrossmintCommonTypes
import Foundation

/// API response model for the wallet activity endpoint.
struct TransferListApiModel: Decodable {
    /// Array of activity events.
    let events: [ActivityEventApiModel]
}

/// API model representing a single activity event.
struct ActivityEventApiModel: Decodable {
    /// The symbol of the token involved in the activity.
    let tokenSymbol: String?

    /// The hash of the token (for NFTs).
    let mintHash: String?

    /// The hash of the transaction.
    let transactionHash: String

    /// The destination address of the transaction.
    let toAddress: String

    /// The source address of the transaction.
    let fromAddress: String

    /// The timestamp when the activity occurred (Unix timestamp).
    let timestamp: Double

    /// The amount of the token involved in the activity.
    let amount: String

    /// The type of activity (e.g., "TRANSFER").
    let type: String

    enum CodingKeys: String, CodingKey {
        case tokenSymbol = "token_symbol"
        case mintHash = "mint_hash"
        case transactionHash = "transaction_hash"
        case toAddress = "to_address"
        case fromAddress = "from_address"
        case timestamp
        case amount
        case type
    }
}
