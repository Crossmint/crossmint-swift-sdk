//
//  CheckoutLineItems.swift
//  Crossmint SDK
//
//  Line items configuration for embedded checkout
//

import Foundation
import Utils

public struct CheckoutLineItems: Codable {
    public let tokenLocator: String?
    public let collectionLocator: String?
    public let executionParameters: [String: AnyCodable]?
    public let callData: [String: AnyCodable]?
    
    public init(
        tokenLocator: String? = nil,
        collectionLocator: String? = nil,
        executionParameters: [String: AnyCodable]? = nil,
        callData: [String: AnyCodable]? = nil
    ) {
        self.tokenLocator = tokenLocator
        self.collectionLocator = collectionLocator
        self.executionParameters = executionParameters
        self.callData = callData
    }
}

