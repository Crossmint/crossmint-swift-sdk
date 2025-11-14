//
//  CrossmintEmbeddedCheckout.swift
//  Crossmint SDK
//
//  Simplified embedded checkout component using webview
//

import SwiftUI

public struct CrossmintEmbeddedCheckout: View {
    private let orderId: String?
    private let clientSecret: String?
    private let lineItems: CheckoutLineItems?
    private let payment: CheckoutPayment?
    private let recipient: CheckoutRecipient?
    private let apiKey: String?
    private let appearance: CheckoutAppearance?
    private let environment: CheckoutEnvironment
    
    public init(
        orderId: String? = nil,
        clientSecret: String? = nil,
        lineItems: CheckoutLineItems? = nil,
        payment: CheckoutPayment? = nil,
        recipient: CheckoutRecipient? = nil,
        apiKey: String? = nil,
        appearance: CheckoutAppearance? = nil,
        environment: CheckoutEnvironment = .staging
    ) {
        self.orderId = orderId
        self.clientSecret = clientSecret
        self.lineItems = lineItems
        self.payment = payment
        self.recipient = recipient
        self.apiKey = apiKey
        self.appearance = appearance
        self.environment = environment
    }
    
    public var body: some View {
        switch checkoutUrlResult {
        case .success(let url):
            CheckoutWebView(url: url)
        case .failure(let error):
            VStack(spacing: 20) {
                Text("Error")
                    .font(.headline)
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    }
    
    private var checkoutUrlResult: Result<String, Error> {
        Result { try generateCheckoutUrl() }
    }
    
    private func generateCheckoutUrl() throws -> String {
        let baseUrl = environment == .production
            ? "https://www.crossmint.com/sdk/2024-03-05/embedded-checkout"
            : "https://staging.crossmint.com/sdk/2024-03-05/embedded-checkout"
        
        let sdkMetadata = ["name": "@crossmint/client-sdk-swift", "version": "1.0.0"]
        
        var queryParams = [
            "sdkMetadata=\(try jsonToURLParam(sdkMetadata))"
        ]
        
        if let orderId = orderId {
            queryParams.append("orderId=\(orderId)")
        }
        
        if let clientSecret = clientSecret {
            queryParams.append("clientSecret=\(clientSecret)")
        }
        
        if let lineItems = lineItems {
            throw CheckoutError.notImplemented("Crossmint Checkout SDK: passing lineItems is not yet implemented")
        }
        
        if let payment = payment {
            queryParams.append("payment=\(try jsonToURLParam(payment.toDictionary()))")
        }
        
        if let recipient = recipient {
            throw CheckoutError.notImplemented("Crossmint Checkout SDK: passing recipient is not yet implemented")
        }
        
        if let appearance = appearance {
            let appearanceDict = appearance.toDictionary()
            if !appearanceDict.isEmpty {
                queryParams.append("appearance=\(try jsonToURLParam(appearanceDict))")
            }
        }
        
        let url = "\(baseUrl)?" + queryParams.joined(separator: "&")
        return url
    }
    
    private func jsonToURLParam(_ object: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
        let json = String(data: data, encoding: .utf8)!
        return encodeQueryValue(json)
    }
    
    private func encodeQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

public enum CheckoutEnvironment {
    case staging
    case production
}

