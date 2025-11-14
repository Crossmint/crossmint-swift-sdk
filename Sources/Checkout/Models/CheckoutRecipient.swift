//
//  CheckoutRecipient.swift
//  Crossmint SDK
//
//  Recipient configuration for embedded checkout
//

import Foundation

public struct CheckoutRecipient {
    public let walletAddress: String?
    public let email: String?
    
    public init(
        walletAddress: String? = nil,
        email: String? = nil
    ) {
        self.walletAddress = walletAddress
        self.email = email
    }
    
    func toDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        if let wallet = walletAddress { dict["walletAddress"] = wallet }
        if let email = email { dict["email"] = email }
        return dict
    }
}

