//
//  CheckoutPayment.swift
//  Crossmint SDK
//
//  Payment configuration for embedded checkout
//

import Foundation

// MARK: - Crypto Payment

public struct CheckoutCryptoPayment {
    public let enabled: Bool
    public let defaultChain: String?
    public let defaultCurrency: String?
    
    public init(
        enabled: Bool,
        defaultChain: String? = nil,
        defaultCurrency: String? = nil
    ) {
        self.enabled = enabled
        self.defaultChain = defaultChain
        self.defaultCurrency = defaultCurrency
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["enabled": enabled]
        if let chain = defaultChain { dict["defaultChain"] = chain }
        if let currency = defaultCurrency { dict["defaultCurrency"] = currency }
        return dict
    }
}

// MARK: - Fiat Payment

public struct CheckoutAllowedMethods {
    public let googlePay: Bool?
    public let applePay: Bool?
    public let card: Bool?
    
    public init(
        googlePay: Bool? = true,
        applePay: Bool? = true,
        card: Bool? = true
    ) {
        self.googlePay = googlePay
        self.applePay = applePay
        self.card = card
    }
    
    func toDictionary() -> [String: Bool] {
        var dict: [String: Bool] = [:]
        if let googlePay = googlePay { dict["googlePay"] = googlePay }
        if let applePay = applePay { dict["applePay"] = applePay }
        if let card = card { dict["card"] = card }
        return dict
    }
}

public struct CheckoutFiatPayment {
    public let enabled: Bool
    public let defaultCurrency: String?
    public let allowedMethods: CheckoutAllowedMethods?
    
    public init(
        enabled: Bool,
        defaultCurrency: String? = nil,
        allowedMethods: CheckoutAllowedMethods? = nil
    ) {
        self.enabled = enabled
        self.defaultCurrency = defaultCurrency
        self.allowedMethods = allowedMethods
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = ["enabled": enabled]
        if let currency = defaultCurrency { dict["defaultCurrency"] = currency }
        if let methods = allowedMethods {
            dict["allowedMethods"] = methods.toDictionary()
        }
        return dict
    }
}

// MARK: - Payment

public struct CheckoutPayment {
    public let crypto: CheckoutCryptoPayment
    public let fiat: CheckoutFiatPayment
    public let receiptEmail: String?
    public let defaultMethod: String? // "fiat" or "crypto"
    
    public init(
        crypto: CheckoutCryptoPayment,
        fiat: CheckoutFiatPayment,
        receiptEmail: String? = nil,
        defaultMethod: String? = nil
    ) {
        self.crypto = crypto
        self.fiat = fiat
        self.receiptEmail = receiptEmail
        self.defaultMethod = defaultMethod
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "crypto": crypto.toDictionary(),
            "fiat": fiat.toDictionary()
        ]
        if let email = receiptEmail { dict["receiptEmail"] = email }
        if let method = defaultMethod { dict["defaultMethod"] = method }
        return dict
    }
}

