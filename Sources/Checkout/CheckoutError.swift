//
//  CheckoutError.swift
//  Crossmint SDK
//
//  Errors for the Checkout module
//

import Foundation

public enum CheckoutError: Error, LocalizedError {
    case notImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .notImplemented(let message):
            return message
        }
    }
}

