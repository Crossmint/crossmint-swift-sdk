//
//  CheckoutLineItems.swift
//  Crossmint SDK
//
//  Line items configuration for embedded checkout
//

import Foundation

public struct CheckoutLineItems {
    public let tokenLocator: String
    public let executionParameters: [String: Any]?
    
    public init(
        tokenLocator: String,
        executionParameters: [String: Any]? = nil
    ) {
        self.tokenLocator = tokenLocator
        self.executionParameters = executionParameters
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["tokenLocator": tokenLocator]
        if let executionParameters = executionParameters {
            dict["executionParameters"] = executionParameters
        }
        return dict
    }
}

