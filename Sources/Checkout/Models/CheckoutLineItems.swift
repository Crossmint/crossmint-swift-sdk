//
//  CheckoutLineItems.swift
//  Crossmint SDK
//
//  Line items configuration for embedded checkout
//

import Foundation

public struct CheckoutLineItems {
    public let tokenLocator: String?
    public let collectionLocator: String?
    public let executionParameters: [String: Any]?
    public let callData: [String: Any]?
    
    public init(
        tokenLocator: String? = nil,
        collectionLocator: String? = nil,
        executionParameters: [String: Any]? = nil,
        callData: [String: Any]? = nil
    ) {
        self.tokenLocator = tokenLocator
        self.collectionLocator = collectionLocator
        self.executionParameters = executionParameters
        self.callData = callData
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let tokenLocator = tokenLocator {
            dict["tokenLocator"] = tokenLocator
        }
        if let collectionLocator = collectionLocator {
            dict["collectionLocator"] = collectionLocator
        }
        if let executionParameters = executionParameters {
            dict["executionParameters"] = executionParameters
        }
        if let callData = callData {
            dict["callData"] = callData
        }
        return dict
    }
}

