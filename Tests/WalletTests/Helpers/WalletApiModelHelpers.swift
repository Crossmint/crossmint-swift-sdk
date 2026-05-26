//
//  WalletApiModelHelpers.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 20/05/26.
//

import Foundation
@testable import Wallet

func makeTestWalletApiModel(address: String = "0x1234567890123456789012345678901234567890") -> WalletApiModel {
    let json = """
    {
        "type": "smart",
        "chainType": "evm",
        "config": {
            "adminSigner": {
                "type": "email",
                "email": "test@example.com",
                "locator": "email:test@example.com"
            }
        },
        "address": "\(address)",
        "linkedUser": "email:test@example.com",
        "createdAt": "2025-01-01T00:00:00.000Z"
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    // swiftlint:disable:next force_try
    return try! decoder.decode(WalletApiModel.self, from: Data(json.utf8))
}
