//
//  StellarAddress.swift
//  CrossmintSDK
//
//  Created by Tomas Martins on 12/22/25.
//

import Foundation

public struct StellarAddress: BlockchainAddress {
    public private(set) var address: String

    public init(address: String) throws(BlockchainAddressError) {
        // Stellar addresses: G (public key) or C (contract) + 55 alphanumeric = 56 total
        guard address.range(of: "^[GC][A-Z0-9]{55}$", options: .regularExpression) != nil else {
            throw BlockchainAddressError.invalidStellarAddress(
                "Invalid Stellar address format: \(address)"
            )
        }
        self.address = address
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(address)
    }

    public var description: String {
        address
    }
}
